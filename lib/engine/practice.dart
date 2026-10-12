/// Practice test engine (spec §7.3).
library;

import 'dart:math';

import '../content/models.dart';
import 'quiz.dart';

/// Splits [total] across domains in proportion to [weights] using the
/// largest-remainder method, never giving a domain more than [available].
/// Any shortfall is filled from domains that still have questions left
/// (including zero-weight ones), largest remaining supply first.
Map<String, int> allocateByWeight({
  required Map<String, int> available,
  required Map<String, num> weights,
  required int total,
}) {
  final supply = {for (final e in available.entries) e.key: e.value};
  final target = min(total, supply.values.fold<int>(0, (a, b) => a + b));
  final alloc = {for (final k in supply.keys) k: 0};

  final weighted = supply.keys.where((k) => (weights[k] ?? 0) > 0).toList();
  final weightSum = weighted.fold<num>(0, (a, k) => a + weights[k]!);
  if (weightSum > 0) {
    final quotas = {
      for (final k in weighted) k: target * weights[k]! / weightSum,
    };
    var assigned = 0;
    for (final k in weighted) {
      alloc[k] = quotas[k]!.floor();
      assigned += alloc[k]!;
    }
    final byRemainder = [...weighted]
      ..sort((a, b) {
        final c = (quotas[b]! - quotas[b]!.floor()).compareTo(
          quotas[a]! - quotas[a]!.floor(),
        );
        return c != 0 ? c : a.compareTo(b);
      });
    for (var i = 0; assigned < target && i < byRemainder.length; i++) {
      alloc[byRemainder[i]] = alloc[byRemainder[i]]! + 1;
      assigned++;
    }
  }

  // Cap at supply, then fill whatever is still short of the target.
  for (final k in alloc.keys) {
    alloc[k] = min(alloc[k]!, supply[k]!);
  }
  var shortfall = target - alloc.values.fold<int>(0, (a, b) => a + b);
  while (shortfall > 0) {
    final candidates = alloc.keys.where((k) => alloc[k]! < supply[k]!).toList()
      ..sort((a, b) {
        final c = (supply[b]! - alloc[b]!).compareTo(supply[a]! - alloc[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    if (candidates.isEmpty) break;
    alloc[candidates.first] = alloc[candidates.first]! + 1;
    shortfall--;
  }
  return alloc;
}

/// Questions eligible for [test]: topics with any domain in the filter.
List<Question> practicePool(PracticeTestDef test, ContentBundle content) {
  final filter = test.filterDomainIds;
  return [
    for (final t in content.topics)
      if (filter == null || t.domainIds.any(filter.contains)) ...t.questions,
  ];
}

List<PresentedQuestion> drawPractice({
  required PracticeTestDef test,
  required ContentBundle content,
  required Random random,
}) {
  final pool = practicePool(test, content);
  List<Question> picked;
  if (test.weighting == PracticeWeighting.uniform) {
    picked = ([...pool]..shuffle(random)).take(test.questionCount).toList();
  } else {
    final byDomain = <String, List<Question>>{};
    for (final q in pool) {
      final d = content.topic(q.topicId)!.primaryDomainId;
      byDomain.putIfAbsent(d, () => []).add(q);
    }
    final alloc = allocateByWeight(
      available: {for (final e in byDomain.entries) e.key: e.value.length},
      weights: {
        for (final d in byDomain.keys) d: content.domain(d)?.weightPercent ?? 0,
      },
      total: test.questionCount,
    );
    picked = [
      for (final e in byDomain.entries)
        ...([...e.value]..shuffle(random)).take(alloc[e.key] ?? 0),
    ]..shuffle(random);
  }
  return [for (final q in picked) present(q, random)];
}

class DomainScore {
  const DomainScore(this.correct, this.total);

  final int correct;
  final int total;

  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  Map<String, dynamic> toJson() => {'correct': correct, 'total': total};
}

/// Per-domain breakdown keyed by each question's topic's primary domain.
Map<String, DomainScore> domainBreakdown(
  QuizAttempt attempt,
  ContentBundle content,
) {
  final correct = <String, int>{};
  final total = <String, int>{};
  for (final p in attempt.questions) {
    final d = content.topic(p.question.topicId)!.primaryDomainId;
    total[d] = (total[d] ?? 0) + 1;
    if (attempt.correct(p)) correct[d] = (correct[d] ?? 0) + 1;
  }
  return {
    for (final d in total.keys) d: DomainScore(correct[d] ?? 0, total[d]!),
  };
}

/// Wall-clock countdown: survives tab throttling because it's derived from
/// the start time, not from tick counts.
class TestTimer {
  const TestTimer({required this.startedAt, required this.limit});

  final DateTime startedAt;

  /// Null when the timer is switched off.
  final Duration? limit;

  Duration elapsed(DateTime now) => now.difference(startedAt);

  Duration? remaining(DateTime now) {
    if (limit == null) return null;
    final left = limit! - elapsed(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool expired(DateTime now) =>
      limit != null && remaining(now) == Duration.zero;
}
