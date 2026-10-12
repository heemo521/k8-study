import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/quiz.dart';

AnswerOption opt(String id, {bool correct = false, String? text}) =>
    AnswerOption(
      id: id,
      text: text ?? 'option $id',
      correct: correct,
      explanation: 'why $id',
    );

Question q(
  String id, {
  QuestionType type = QuestionType.single,
  List<AnswerOption>? options,
}) => Question(
  id: id,
  topicId: 't',
  type: type,
  stem: 'stem',
  options: options ?? [opt('a', correct: true), opt('b'), opt('c'), opt('d')],
  sourceUrl: 'https://kubernetes.io/docs/',
  difficulty: 1,
);

void main() {
  test('grading is independent of shuffled display order', () {
    final question = q('q1');
    final orders = <String>{};
    for (var seed = 0; seed < 20; seed++) {
      final p = present(question, Random(seed));
      orders.add(p.options.map((o) => o.id).join());
      // Find the correct option wherever it landed and pick it by id.
      final correctId = p.options.firstWhere((o) => o.correct).id;
      expect(isCorrect(question, {correctId}), isTrue);
      expect(
        isCorrect(question, {p.options.first.id}),
        p.options.first.id == 'a',
      );
    }
    expect(orders.length, greaterThan(1), reason: 'options should be shuffled');
  });

  test('true/false always shows True then False', () {
    final question = q(
      'tf',
      type: QuestionType.truefalse,
      options: [
        opt('f', text: 'False'),
        opt('t', text: 'True', correct: true),
      ],
    );
    for (var seed = 0; seed < 10; seed++) {
      expect(present(question, Random(seed)).options.map((o) => o.text), [
        'True',
        'False',
      ]);
    }
  });

  test('multi requires an exact set match (no partial credit)', () {
    final question = q(
      'm',
      type: QuestionType.multi,
      options: [opt('a', correct: true), opt('b', correct: true), opt('c')],
    );
    expect(isCorrect(question, {'a', 'b'}), isTrue);
    expect(isCorrect(question, {'a'}), isFalse);
    expect(isCorrect(question, {'a', 'b', 'c'}), isFalse);
    expect(isCorrect(question, {}), isFalse);
  });

  test('drawQuiz takes 10 without replacement and prioritises missed', () {
    final bank = [for (var i = 0; i < 15; i++) q('q$i')];
    final drawn = drawQuiz(
      bank: bank,
      random: Random(3),
      priorityIds: {'q13', 'q14'},
    );
    final ids = drawn.map((p) => p.question.id).toList();
    expect(ids.length, quizLength);
    expect(ids.toSet().length, quizLength);
    expect(ids, containsAll(['q13', 'q14']));
  });

  test('QuizAttempt scoring and missed set', () {
    final bank = [q('a'), q('b'), q('c'), q('d')];
    final attempt = QuizAttempt([for (final x in bank) present(x, Random(0))]);
    attempt.answer('a', {'a'});
    attempt.answer('b', {'a'});
    attempt.answer('c', {'b'});
    // 'd' unanswered counts as wrong.
    expect(attempt.correctCount, 2);
    expect(attempt.percent, 50);
    expect(attempt.missedIds, {'c', 'd'});
    expect(attempt.unansweredCount, 1);
  });
}
