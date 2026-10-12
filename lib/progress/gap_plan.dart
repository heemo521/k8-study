import '../content/models.dart';
import '../engine/quiz.dart';
import 'insights.dart';
import 'progress_store.dart';

/// Builds a gap plan from a finished exam: every competency whose exam score
/// (unanswered counts as not correct) is below the mastery bar, worst first.
/// Returns null when the exam showed no gaps.
GapPlan? planFromAttempt(
  QuizAttempt attempt, {
  required String testId,
  required DateTime now,
}) {
  final correct = <String, int>{};
  final total = <String, int>{};
  for (final p in attempt.questions) {
    final c = p.question.competencyId;
    if (c == null) continue;
    total[c] = (total[c] ?? 0) + 1;
    if (attempt.correct(p)) correct[c] = (correct[c] ?? 0) + 1;
  }
  final items =
      [
        for (final c in total.keys)
          if ((correct[c] ?? 0) * 100 < masteryPercent * total[c]!)
            GapItem(
              competencyId: c,
              examCorrect: correct[c] ?? 0,
              examTotal: total[c]!,
            ),
      ]..sort(
        (a, b) => (a.examCorrect / a.examTotal).compareTo(
          b.examCorrect / b.examTotal,
        ),
      );
  if (items.isEmpty) return null;
  return GapPlan(testId: testId, createdAt: now, items: items);
}

/// Where one plan item stands. The three steps are derived from progress:
/// read the notes of the topics that teach it, review their flashcards, and
/// get the competency to mastery in a targeted quiz ([fixed]).
class GapItemStatus {
  const GapItemStatus({
    required this.item,
    required this.competency,
    required this.domain,
    required this.topics,
    required this.notesDone,
    required this.cardsDone,
    required this.stats,
  });

  final GapItem item;
  final Competency competency;
  final Domain domain;

  /// Topics that teach this competency, in study order.
  final List<Topic> topics;
  final bool notesDone;
  final bool cardsDone;

  /// Current accuracy for the competency (latest answers).
  final CompetencyGap stats;

  bool get fixed => !stats.isGap;
  int get stepsDone => [notesDone, cardsDone, fixed].where((d) => d).length;

  /// First topic whose notes aren't fully read (else the first topic).
  Topic? notesTopic(ProgressStore p) => topics.isEmpty
      ? null
      : topics.firstWhere(
          (t) => p.readCount(t) < t.sections.length,
          orElse: () => topics.first,
        );

  /// First topic with flashcards never reviewed (else the first topic).
  Topic? cardsTopic(ProgressStore p) => topics.isEmpty
      ? null
      : topics.firstWhere(
          (t) => t.flashcards.any((c) => p.cardState(c.id) == null),
          orElse: () => topics.first,
        );
}

/// Status of every item in [plan] that still exists in [content].
List<GapItemStatus> planStatus(
  ContentBundle content,
  ProgressStore p,
  GapPlan plan,
) {
  final gaps = {for (final g in competencyGaps(content, p)) g.competency.id: g};
  return [
    for (final item in plan.items)
      if (gaps[item.competencyId] case final stats?)
        () {
          // Most relevant first: topics with the most questions on the
          // competency, then those that declare it, then study order.
          double relevance(Topic t) =>
              t.questions
                  .where((q) => q.competencyId == item.competencyId)
                  .length +
              (t.competencyIds.contains(item.competencyId) ? 0.5 : 0);
          final topics = [
            for (final t in content.topics)
              if (relevance(t) > 0) t,
          ]..sort((a, b) => relevance(b).compareTo(relevance(a)));
          return GapItemStatus(
            item: item,
            competency: stats.competency,
            domain: stats.domain,
            topics: topics,
            notesDone: topics.every((t) => p.readCount(t) >= t.sections.length),
            cardsDone: topics.every(
              (t) => t.flashcards.every((c) => p.cardState(c.id) != null),
            ),
            stats: stats,
          );
        }(),
  ];
}

/// Questions for "Re-test my gaps": every question of the plan's open items.
List<Question> planPool(ContentBundle content, ProgressStore p) {
  final plan = p.gapPlan(content.subject.id);
  if (plan == null) return const [];
  final open = {
    for (final s in planStatus(content, p, plan))
      if (!s.fixed) s.item.competencyId,
  };
  return content.allQuestions
      .where((q) => open.contains(q.competencyId))
      .toList();
}
