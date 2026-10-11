/// Derived views over progress: where the learner is, and where the gaps are.
library;

import '../content/models.dart';
import '../engine/flashcards.dart' as fc;
import '../engine/quiz.dart';
import 'progress_store.dart';

enum TopicStep { notes, cards, quiz, done }

/// The next step for a topic, in loop order (notes → cards → quiz).
TopicStep nextStep(Topic topic, ProgressStore p) {
  if (!p.notesComplete(topic)) return TopicStep.notes;
  if (!topic.flashcards.any((c) => p.cardState(c.id) != null)) {
    return TopicStep.cards;
  }
  if (!p.quizPassed(topic.id)) return TopicStep.quiz;
  return TopicStep.done;
}

String stepLabel(TopicStep step) => switch (step) {
  TopicStep.notes => 'Read the notes',
  TopicStep.cards => 'Review flashcards',
  TopicStep.quiz => 'Take the quiz',
  TopicStep.done => 'Complete',
};

String stepPath(Topic topic, TopicStep step) => switch (step) {
  TopicStep.notes => '/topic/${topic.id}/notes',
  TopicStep.cards => '/topic/${topic.id}/cards',
  TopicStep.quiz => '/topic/${topic.id}/quiz',
  TopicStep.done => '/topic/${topic.id}',
};

class NextAction {
  const NextAction({
    required this.topic,
    required this.step,
    required this.position,
    required this.total,
    required this.resuming,
  });

  final Topic topic;
  final TopicStep step;

  /// 1-based position of [topic] in the recommended study order.
  final int position;
  final int total;

  /// True when continuing the most recently opened topic.
  final bool resuming;
}

/// The recently opened topic if it isn't complete, else the next incomplete
/// topic after it in study order (wrapping). Null when everything is complete.
NextAction? nextAction(ContentBundle content, ProgressStore p) {
  final topics = content.topics;
  NextAction build(Topic t, bool resuming) => NextAction(
    topic: t,
    step: nextStep(t, p),
    position: topics.indexOf(t) + 1,
    total: topics.length,
    resuming: resuming,
  );

  final recent = content.topic(p.recentTopic(content.subject.id) ?? '');
  if (recent != null && !p.topicComplete(recent)) return build(recent, true);
  // Move forward from the last topic studied, then wrap to earlier gaps.
  final start = recent == null ? 0 : topics.indexOf(recent) + 1;
  for (var i = 0; i < topics.length; i++) {
    final t = topics[(start + i) % topics.length];
    if (!p.topicComplete(t)) return build(t, false);
  }
  return null;
}

class DomainReadiness {
  const DomainReadiness({
    required this.domain,
    required this.topics,
    required this.topicsComplete,
    required this.progress,
    required this.questionsSeen,
    required this.questionsTotal,
    required this.accuracy,
  });

  final Domain domain;
  final List<Topic> topics;
  final int topicsComplete;

  /// Mean topic progress (notes + quiz mastery), 0..1.
  final double progress;
  final int questionsSeen;
  final int questionsTotal;

  /// Share of seen questions whose latest answer was right; null if none seen.
  final double? accuracy;

  bool get hasContent => topics.isNotEmpty;
}

/// Readiness for every domain, in display order. Topics count toward their
/// primary domain.
List<DomainReadiness> domainReadiness(ContentBundle content, ProgressStore p) {
  return [
    for (final d in content.domainsInDisplayOrder)
      () {
        final topics = content.topicsForDomain(d.id);
        final questions = topics.expand((t) => t.questions).toList();
        final seen = [
          for (final q in questions)
            if (p.answerStats(q.id) != null) p.answerStats(q.id)!,
        ];
        return DomainReadiness(
          domain: d,
          topics: topics,
          topicsComplete: topics.where(p.topicComplete).length,
          progress: topics.isEmpty
              ? 0
              : topics.map(p.topicProgress).reduce((a, b) => a + b) /
                    topics.length,
          questionsSeen: seen.length,
          questionsTotal: questions.length,
          accuracy: seen.isEmpty
              ? null
              : seen.where((s) => s.lastCorrect).length / seen.length,
        );
      }(),
  ];
}

class CompetencyGap {
  const CompetencyGap({
    required this.competency,
    required this.domain,
    required this.questionIds,
    required this.seen,
    required this.rightLastTime,
  });

  final Competency competency;
  final Domain domain;
  final List<String> questionIds;
  final int seen;
  final int rightLastTime;

  int get total => questionIds.length;
  double? get accuracy => seen == 0 ? null : rightLastTime / seen;

  /// Below mastery on what's been answered, or less than half covered.
  bool get isGap =>
      (accuracy != null && accuracy! * 100 < masteryPercent) ||
      seen * 2 < total;
}

/// Competencies that have questions, weakest first: answered-and-weak, then
/// least covered, then strong.
List<CompetencyGap> competencyGaps(ContentBundle content, ProgressStore p) {
  final byCompetency = <String, List<String>>{};
  for (final q in content.allQuestions) {
    final c = q.competencyId;
    if (c != null) byCompetency.putIfAbsent(c, () => []).add(q.id);
  }
  final gaps = [
    for (final e in byCompetency.entries)
      if (content.competency(e.key) != null)
        CompetencyGap(
          competency: content.competency(e.key)!,
          domain: content.domainOfCompetency(e.key)!,
          questionIds: e.value,
          seen: e.value.where((id) => p.answerStats(id) != null).length,
          rightLastTime: e.value
              .where((id) => p.answerStats(id)?.lastCorrect ?? false)
              .length,
        ),
  ];
  double rank(CompetencyGap g) =>
      g.accuracy ?? (g.seen == 0 ? 0.5 : 1.0); // unseen sits mid-table
  gaps.sort((a, b) {
    final c = rank(a).compareTo(rank(b));
    return c != 0 ? c : (a.seen / a.total).compareTo(b.seen / b.total);
  });
  return gaps;
}

/// Started-but-not-complete topics, least progress first.
List<Topic> weakTopics(ContentBundle content, ProgressStore p) =>
    content.topics
        .where((t) => p.topicStarted(t) && !p.topicComplete(t))
        .toList()
      ..sort((a, b) => p.topicProgress(a).compareTo(p.topicProgress(b)));

/// Questions whose most recent answer was wrong.
List<Question> missedQuestions(ContentBundle content, ProgressStore p) => [
  for (final q in content.allQuestions)
    if (p.answerStats(q.id)?.lastCorrect == false) q,
];

int dueCardCount(ContentBundle content, ProgressStore p, DateTime now) =>
    content.allFlashcards
        .where((c) => p.cardState(c.id)?.isDue(now) ?? false)
        .length;

/// Due cards (seen before and due now) across the subject.
List<Flashcard> dueCards(
  ContentBundle content,
  ProgressStore p,
  DateTime now,
) => content.allFlashcards
    .where((c) => p.cardState(c.id)?.isDue(now) ?? false)
    .toList();

/// Questions for a review quiz.
List<Question> reviewPool(
  ContentBundle content,
  ProgressStore p, {
  required String kind,
  String? id,
}) {
  switch (kind) {
    case 'missed':
      return missedQuestions(content, p);
    case 'competency':
      return content.allQuestions.where((q) => q.competencyId == id).toList();
    case 'domain':
      return content
          .topicsForDomain(id ?? '')
          .expand((t) => t.questions)
          .toList();
    default:
      return const [];
  }
}

/// Re-exported so screens only import insights for card counts.
int topicDueCount(Topic t, ProgressStore p, DateTime now) =>
    fc.dueCount(t.flashcards, p.cardStates, now);
