/// Topic quiz engine (spec §7.2) and shared question presentation/grading.
library;

import 'dart:math';

import '../content/models.dart';
import 'command_grading.dart';

const quizLength = 10;
const warmupLength = 3;

/// Topic mastery threshold. An app-internal bar, not a CKA pass mark.
const masteryPercent = 80;

/// A question as shown in one attempt: options in display order.
class PresentedQuestion {
  const PresentedQuestion(this.question, this.options);

  final Question question;
  final List<AnswerOption> options;
}

/// Shuffles option order for one attempt (Fisher–Yates via [List.shuffle]).
/// True/false always shows True then False. Grading uses option ids, so the
/// display order never affects the result.
PresentedQuestion present(Question q, Random random) {
  final options = [...q.options];
  if (q.type == QuestionType.truefalse) {
    options.sort((a, b) => a.text == 'True' ? -1 : (b.text == 'True' ? 1 : 0));
  } else {
    options.shuffle(random);
  }
  return PresentedQuestion(q, options);
}

/// Exact-set grading: single/truefalse need the one correct id, multi needs
/// exactly the correct set (no partial credit). A command answer is the typed
/// text as the only element, graded by [commandMatches].
bool isCorrect(Question q, Set<String> selected) {
  if (q.type == QuestionType.command) {
    return selected.length == 1 && commandMatches(selected.first, q.answers);
  }
  final correct = q.correctIds;
  return selected.length == correct.length && selected.containsAll(correct);
}

/// Draws [count] questions without replacement from [bank], taking questions
/// listed in [priorityIds] (missed last time) first, then filling at random.
List<PresentedQuestion> drawQuiz({
  required List<Question> bank,
  required Random random,
  Set<String> priorityIds = const {},
  int count = quizLength,
}) {
  final priority = bank.where((q) => priorityIds.contains(q.id)).toList()
    ..shuffle(random);
  final rest = bank.where((q) => !priorityIds.contains(q.id)).toList()
    ..shuffle(random);
  final picked = [...priority, ...rest].take(count).toList()..shuffle(random);
  return [for (final q in picked) present(q, random)];
}

/// Questions to try before reading the notes (spec §15.6): the easiest
/// multiple-choice ones, since typing a command cold is a guess too far.
List<PresentedQuestion> drawWarmup({
  required List<Question> bank,
  required Random random,
  int count = warmupLength,
}) {
  final pool = bank.where((q) => q.type != QuestionType.command).toList()
    ..shuffle(random)
    ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
  return [for (final q in pool.take(count)) present(q, random)];
}

/// One run through a list of presented questions.
class QuizAttempt {
  QuizAttempt(this.questions);

  final List<PresentedQuestion> questions;
  final Map<String, Set<String>> answers = {};

  /// Questions answered with "Not sure" (spec §15.1).
  final Set<String> unsure = {};

  void answer(String questionId, Set<String> selected, {bool sure = true}) {
    answers[questionId] = Set.unmodifiable(selected);
    if (sure) {
      unsure.remove(questionId);
    } else {
      unsure.add(questionId);
    }
  }

  bool isSure(String questionId) => !unsure.contains(questionId);

  bool isAnswered(String questionId) =>
      (answers[questionId] ?? const {}).isNotEmpty;

  bool correct(PresentedQuestion p) =>
      isCorrect(p.question, answers[p.question.id] ?? const {});

  int get correctCount => questions.where(correct).length;

  int get percent =>
      questions.isEmpty ? 0 : (correctCount * 100 / questions.length).round();

  int get unansweredCount =>
      questions.where((p) => !isAnswered(p.question.id)).length;

  Set<String> get missedIds => {
    for (final p in questions)
      if (!correct(p)) p.question.id,
  };

  /// Wrong answers given with "Sure": the misconceptions worth fixing first.
  int get confidentMistakes => questions
      .where((p) => isAnswered(p.question.id))
      .where((p) => !correct(p) && isSure(p.question.id))
      .length;

  /// Right answers given with "Not sure": they come back for review.
  int get luckyGuesses =>
      questions.where((p) => correct(p) && !isSure(p.question.id)).length;
}
