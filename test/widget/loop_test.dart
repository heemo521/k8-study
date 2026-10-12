// Done-criteria §11.1/§11.4: one full study → flashcards → quiz loop at a
// 390×844 phone viewport, with progress persisted.
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/progress/insights.dart';
import 'package:k8_study/progress/progress_store.dart';
import 'package:k8_study/widgets/question_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Answers the visible quiz question correctly (or deliberately wrong).
Future<void> answerCurrent(
  WidgetTester tester, {
  required bool correctly,
}) async {
  final view = tester.widget<QuestionView>(find.byType(QuestionView));
  final q = view.presented.question;
  final picks = correctly
      ? q.options.where((o) => o.correct)
      : [q.options.firstWhere((o) => !o.correct)];
  for (final o in picks) {
    final f = find.descendant(
      of: find.byType(QuestionView),
      matching: find.text(o.text),
    );
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }
  await tapKey(tester, 'submit');
}

void main() {
  testWidgets('study → flashcards → quiz → results → retry missed', (
    tester,
  ) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    const topicId = 'namespaces';
    final topic = h.content.topic(topicId)!;

    // S1 → S2
    expect(
      find.text('0 of ${h.content.topics.length} topics complete'),
      findsOneWidget,
    );
    await tapKey(tester, 'topic-card-$topicId');
    expect(find.text(topic.title), findsWidgets);

    // S2 → S3: read every section (scrolling marks them; tap any leftovers).
    await tapKey(tester, 'step-notes');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('next-flashcards')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    for (final s in topic.sections) {
      final mark = find.byKey(ValueKey('mark-read-${s.id}'));
      if (mark.evaluate().isNotEmpty) await tapKey(tester, 'mark-read-${s.id}');
    }
    expect(h.progress.notesComplete(topic), isTrue);
    expect(
      find.text('${topic.sections.length}/${topic.sections.length}'),
      findsOneWidget,
    );

    // S3 → S4: review every card in the session.
    await tapKey(tester, 'next-flashcards');
    var guard = 0;
    while (find.byKey(const ValueKey('cards-summary')).evaluate().isEmpty) {
      await tapKey(tester, 'flip');
      await tapKey(tester, 'got-it');
      expect(++guard, lessThan(50));
    }
    expect(
      topic.flashcards.every((c) => h.progress.cardState(c.id)?.box == 2),
      isTrue,
    );

    // S4 → S5: 10 questions, first one wrong.
    await tapKey(tester, 'next-quiz');
    for (var i = 0; i < 10; i++) {
      expect(find.text('Q ${i + 1}/10'), findsOneWidget);
      await answerCurrent(tester, correctly: i != 0);
      await tapKey(tester, 'next');
    }

    // S6
    expect(find.text('90%'), findsOneWidget);
    expect(find.textContaining('Topic mastered'), findsOneWidget);
    expect(h.progress.quizStats(topicId)!.bestPct, 90);
    expect(h.progress.topicComplete(topic), isTrue);

    // Retry missed: one question, doesn't change best score.
    await tapKey(tester, 'retry-missed');
    expect(find.text('Q 1/1'), findsOneWidget);
    await answerCurrent(tester, correctly: true);
    await tapKey(tester, 'next');
    expect(find.text('Retry results'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(h.progress.quizStats(topicId)!.bestPct, 90);
    expect(h.progress.quizStats(topicId)!.attempts, 1);
    expect(h.progress.quizStats(topicId)!.missed, isEmpty);

    // Progress survives a "reload" (new store over the same storage).
    final reloaded = ProgressStore(await SharedPreferences.getInstance());
    expect(reloaded.topicComplete(topic), isTrue);
    expect(reloaded.cardState(topic.flashcards.first.id)?.box, 2);
  });

  testWidgets('practice test runs to the per-domain breakdown', (tester) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester, initialLocation: '/practice');
    await tapKey(tester, 'practice-cluster-arch');
    await tapKey(tester, 'start-test');
    final test = h.content.practiceTest('cluster-arch')!;
    expect(find.text('Q 1/${test.questionCount}'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-timer')), findsOneWidget);

    // Answer the first question, flag the second, leave the rest blank.
    final view = tester.widget<QuestionView>(find.byType(QuestionView));
    final correct = view.presented.question.options.firstWhere(
      (o) => o.correct,
    );
    await tester.tap(
      find
          .descendant(
            of: find.byType(QuestionView),
            matching: find.text(correct.text),
          )
          .first,
    );
    await tester.pumpAndSettle();
    // Deferred feedback: no verdict shown.
    expect(find.textContaining('Correct'), findsNothing);
    await tapKey(tester, 'practice-next');
    await tapKey(tester, 'flag');
    expect(find.text('Flagged for review'), findsOneWidget);

    await tester.tap(find.text('Finish test'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'confirm-finish');

    expect(find.byKey(const ValueKey('practice-score')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('breakdown-cluster-arch')),
      findsOneWidget,
    );
    expect(
      h.progress.practiceHistory.single.perDomain['cluster-arch']!.total,
      test.questionCount,
    );
    // Skipped questions score as wrong but aren't recorded as evidence.
    expect(
      find.textContaining('${test.questionCount - 1} unanswered'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('review-missed-after-test')),
      findsNothing,
    );
    expect(missedQuestions(h.content, h.progress), isEmpty);
    expect(
      h.progress.answerStats(view.presented.question.id)?.lastCorrect,
      isTrue,
    );
  });

  testWidgets('timer expiry auto-finishes the test', (tester) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester, initialLocation: '/practice/mixed/run');
    expect(find.byKey(const ValueKey('practice-timer')), findsOneWidget);
    h.clock.t = testNow.add(const Duration(minutes: 36));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('practice-score')), findsOneWidget);
  });

  testWidgets('every top-level screen lays out at 360px without overflow', (
    tester,
  ) async {
    await setPhoneViewport(tester, size: const Size(360, 740));
    for (final path in [
      '/',
      '/topic/kubeadm',
      '/topic/kubeadm/notes',
      '/topic/architecture/notes',
      '/topic/kubeadm/cards',
      '/topic/kubeadm/quiz',
      '/practice',
      '/progress',
      '/about',
    ]) {
      await pumpApp(tester, initialLocation: path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });

  testWidgets('screens lay out at 360px with 200% text without overflow', (
    tester,
  ) async {
    await setPhoneViewport(tester, size: const Size(360, 740));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final path in [
      '/',
      '/topic/kubeadm',
      '/topic/kubeadm/notes',
      '/topic/kubeadm/cards',
      '/topic/kubeadm/quiz',
      '/practice',
      '/practice/mixed/run',
      '/progress',
      '/progress/review?kind=missed',
      '/search',
      '/about',
    ]) {
      await pumpApp(tester, initialLocation: path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}
