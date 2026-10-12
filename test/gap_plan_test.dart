import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/content_loader.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/quiz.dart';
import 'package:k8_study/progress/gap_plan.dart';
import 'package:k8_study/progress/insights.dart';
import 'package:k8_study/progress/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;
  final now = DateTime(2026, 10, 12);

  setUpAll(() async {
    content = (await ContentLoader(rootBundle).load()).subject('kubernetes');
  });

  Future<ProgressStore> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return ProgressStore(await SharedPreferences.getInstance());
  }

  /// Questions of competency [c], answered right for the first [right].
  QuizAttempt attemptFor(Map<String, int> rightByCompetency, int each) {
    final picked = <PresentedQuestion>[];
    final attempt = QuizAttempt(picked);
    for (final e in rightByCompetency.entries) {
      final qs = content.allQuestions
          .where((q) => q.competencyId == e.key)
          .take(each)
          .toList();
      for (final (i, q) in qs.indexed) {
        picked.add(PresentedQuestion(q, q.options));
        final opt = i < e.value
            ? {
                for (final o in q.options)
                  if (o.correct) o.id,
              }
            : {q.options.firstWhere((o) => !o.correct).id};
        attempt.answer(q.id, opt);
      }
    }
    return attempt;
  }

  String competencyWithMost() {
    final counts = <String, int>{};
    for (final q in content.allQuestions) {
      final c = q.competencyId;
      if (c != null) counts[c] = (counts[c] ?? 0) + 1;
    }
    return (counts.entries.toList()..sort((a, b) => b.value - a.value))
        .first
        .key;
  }

  test('plan holds the competencies under 80%, worst first', () {
    final ids = content.allQuestions
        .map((q) => q.competencyId)
        .whereType<String>()
        .toSet()
        .take(3)
        .toList();
    final attempt = attemptFor({ids[0]: 5, ids[1]: 1, ids[2]: 3}, 5);
    final plan = planFromAttempt(attempt, testId: 'cka-mock', now: now)!;
    expect(plan.items.map((i) => i.competencyId), [ids[1], ids[2]]);
    expect(plan.items.first.examCorrect, 1);
    expect(plan.items.first.examTotal, 5);
    expect(
      planFromAttempt(attemptFor({ids[0]: 5}, 5), testId: 'x', now: now),
      isNull,
    );
  });

  test('plans persist per subject, back up, and reset', () async {
    final p = await fresh();
    final plan = GapPlan(
      testId: 'cka-mock',
      createdAt: now,
      items: const [GapItem(competencyId: 'c1', examCorrect: 1, examTotal: 4)],
    );
    p.setGapPlan('kubernetes', plan);
    final reloaded = ProgressStore(await SharedPreferences.getInstance());
    expect(reloaded.gapPlan('kubernetes')!.items.single.competencyId, 'c1');
    expect(reloaded.gapPlan('docker'), isNull);

    final backup = p.exportJson();
    await p.resetProgress();
    expect(p.gapPlan('kubernetes'), isNull);
    await p.importJson(backup);
    expect(p.gapPlan('kubernetes')!.testId, 'cka-mock');
    p.clearGapPlan('kubernetes');
    expect(p.gapPlan('kubernetes'), isNull);
  });

  test('steps are derived from progress; fixed at mastery', () async {
    final p = await fresh();
    final c = competencyWithMost();
    final plan = planFromAttempt(attemptFor({c: 0}, 3), testId: 't', now: now)!;
    p.setGapPlan(content.subject.id, plan);

    var status = planStatus(content, p, plan).single;
    expect(status.topics, isNotEmpty);
    expect(
      [status.notesDone, status.cardsDone, status.fixed],
      [false, false, false],
    );

    for (final t in status.topics) {
      for (final s in t.sections) {
        p.markSectionRead(t.id, s.id);
      }
    }
    status = planStatus(content, p, plan).single;
    expect(status.notesDone, isTrue);
    expect(status.stepsDone, 1);

    // Answer every question of the competency correctly.
    final qs = content.allQuestions.where((q) => q.competencyId == c);
    final right = QuizAttempt([
      for (final q in qs) PresentedQuestion(q, q.options),
    ]);
    for (final q in qs) {
      right.answer(q.id, {
        for (final o in q.options)
          if (o.correct) o.id,
      });
    }
    p.recordAnswers(right);
    status = planStatus(content, p, plan).single;
    expect(status.fixed, isTrue);
    expect(planPool(content, p), isEmpty, reason: 'nothing left to re-test');
  });

  test('re-test pool covers only open gaps', () async {
    final p = await fresh();
    final c = competencyWithMost();
    final plan = planFromAttempt(attemptFor({c: 0}, 3), testId: 't', now: now)!;
    p.setGapPlan(content.subject.id, plan);
    final pool = reviewPool(content, p, kind: 'plan', now: now);
    expect(pool, isNotEmpty);
    expect(pool.every((q) => q.competencyId == c), isTrue);
  });
}
