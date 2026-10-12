// "Where am I" and "where are my gaps": continue card, gap analysis, review
// quizzes, due-card review, search, and the subject switcher.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/flashcards.dart';
import 'package:k8_study/engine/quiz.dart';
import 'package:k8_study/progress/insights.dart';
import 'package:k8_study/widgets/question_view.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('continue card starts at topic 1, then resumes the last topic', (
    tester,
  ) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    final first = h.content.topics.first;
    expect(find.textContaining('Start here · Topic 1 of'), findsOneWidget);
    expect(find.text(first.title), findsWidgets);

    // Open a later topic: the card now offers to continue it.
    final later = h.content.topics[3];
    h.progress.markTopicVisited(h.content.subject.id, later.id);
    await tester.pumpAndSettle();
    expect(find.textContaining('Continue · Topic 4 of'), findsOneWidget);
    await tapKey(tester, 'continue-button');
    expect(
      find.byKey(const ValueKey('sections-menu')),
      findsOneWidget,
      reason: 'continue opens the notes step',
    );
    expect(find.text(later.title), findsOneWidget);
  });

  testWidgets('gap analysis lists weak competencies and reviews them', (
    tester,
  ) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester, initialLocation: '/progress');
    expect(find.textContaining('Take a quiz or practice test'), findsOneWidget);

    // Answer every question of one competency wrong.
    final gaps = competencyGaps(h.content, h.progress);
    final target = gaps.first;
    final questions = [
      for (final id in target.questionIds) h.content.question(id)!,
    ];
    final attempt = QuizAttempt([
      for (final q in questions) PresentedQuestion(q, q.options),
    ]);
    for (final q in questions) {
      attempt.answer(q.id, {q.options.firstWhere((o) => !o.correct).id});
    }
    h.progress.recordAnswers(attempt);
    await tester.pumpAndSettle();

    final tile = find.byKey(ValueKey('gap-${target.competency.id}'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: tile, matching: find.text('0% right')),
      findsOneWidget,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();

    // A review quiz drawn from that competency.
    final view = tester.widget<QuestionView>(find.byType(QuestionView));
    expect(view.presented.question.competencyId, target.competency.id);
    expect(find.textContaining('From: '), findsOneWidget);
  });

  testWidgets('missed questions review runs and records answers', (
    tester,
  ) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    final q = h.content.topics.first.questions.first;
    h.progress.recordAnswers(
      QuizAttempt([PresentedQuestion(q, q.options)])
        ..answer(q.id, {q.options.firstWhere((o) => !o.correct).id}),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chip-missed')), findsOneWidget);
    await tapKey(tester, 'chip-missed');
    expect(find.text('Q 1/1'), findsOneWidget);
    final correct = q.options.firstWhere((o) => o.correct);
    final f = find.descendant(
      of: find.byType(QuestionView),
      matching: find.text(correct.text),
    );
    await tester.tap(f.first);
    await tester.pumpAndSettle();
    await tapKey(tester, 'submit');
    await tapKey(tester, 'next');
    expect(find.text('Review results'), findsOneWidget);
    expect(h.progress.answerStats(q.id)!.lastCorrect, isTrue);
    expect(missedQuestions(h.content, h.progress), isEmpty);
  });

  testWidgets('due flashcards across topics are reviewed in one session', (
    tester,
  ) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    final cards = [
      h.content.topics[0].flashcards.first,
      h.content.topics[1].flashcards.first,
    ];
    for (final c in cards) {
      h.progress.setCardState(c.id, CardState(box: 2, dueAt: testNow));
    }
    await tester.pumpAndSettle();
    expect(find.text('2 cards due'), findsOneWidget);
    await tapKey(tester, 'chip-due-cards');
    expect(find.text('Due flashcards'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tapKey(tester, 'flip');
      await tapKey(tester, 'got-it');
    }
    expect(find.byKey(const ValueKey('cards-summary')), findsOneWidget);
    expect(cards.every((c) => h.progress.cardState(c.id)!.box == 3), isTrue);
  });

  testWidgets('search finds a note section and jumps to it', (tester) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    await tapKey(tester, 'open-search');
    await tester.enterText(
      find.byKey(const ValueKey('search-field')),
      'kube-node-lease',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('results'), findsOneWidget);
    // First section hit for the namespaces topic.
    final hit = find.text('The four initial namespaces');
    await tester.tap(hit.first);
    await tester.pumpAndSettle();
    expect(find.text('Namespaces'), findsWidgets);
    expect(h.progress.recentTopic(h.content.subject.id), 'namespaces');
  });

  testWidgets(
    'subject switcher appears with 2+ subjects and switches content',
    (tester) async {
      await setPhoneViewport(tester);
      final real = (await loadCatalog(tester)).subjects.first;
      final fake = ContentBundle(
        subject: SubjectInfo(
          id: 'docker',
          title: 'Docker',
          tagline: 'Containers',
          description: 'Test subject',
          contentVersion: 1,
          reviewedAt: '2026-10-11',
          exam: null,
          domains: const [
            Domain(
              id: 'basics',
              title: 'Basics',
              weightPercent: null,
              isExamDomain: false,
              competencies: [],
            ),
          ],
          topicIds: const ['docker-intro'],
          sourceAllowlist: const [],
          attributions: const [],
          trademarks: const [],
        ),
        topics: const [
          Topic(
            id: 'docker-intro',
            title: 'Docker Intro',
            summary: 'What it is',
            order: 1,
            domainIds: ['basics'],
            competencyIds: [],
            estMinutes: 5,
            reviewedAt: '2026-10-11',
            sections: [],
            flashcards: [],
            questions: [],
          ),
        ],
        practiceTests: const [],
      );
      await pumpApp(tester, catalog: Catalog([real, fake]));
      await tapKey(tester, 'subject-switcher');
      await tapKey(tester, 'subject-docker');
      expect(find.text('Docker'), findsWidgets);
      expect(find.text('Docker Intro'), findsWidgets);
      expect(find.text('Basics'), findsOneWidget);
    },
  );

  testWidgets('domain sections collapse and expand', (tester) async {
    await setPhoneViewport(tester);
    await pumpApp(tester);
    final card = find.byKey(const ValueKey('topic-card-what-is-k8s'));
    expect(card, findsOneWidget);
    await tapKey(tester, 'domain-foundations');
    expect(card, findsNothing);
    await tapKey(tester, 'domain-foundations');
    expect(card, findsOneWidget);
  });

  testWidgets('quiz keyboard: digit selects, Enter submits and advances', (
    tester,
  ) async {
    await setPhoneViewport(tester, size: const Size(1024, 900));
    await pumpApp(tester, initialLocation: '/topic/namespaces/quiz');
    expect(find.text('1'), findsWidgets, reason: 'shortcut hints on desktop');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('next')),
      findsOneWidget,
      reason: 'Enter submitted the answer',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Q 2/10'), findsOneWidget);
  });

  testWidgets('flashcard keyboard: Space flips, 2 = got it', (tester) async {
    await setPhoneViewport(tester, size: const Size(1024, 900));
    final h = await pumpApp(tester, initialLocation: '/topic/namespaces/cards');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('ANSWER'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(find.text('PROMPT'), findsOneWidget);
    final cards = h.content.topic('namespaces')!.flashcards;
    expect(cards.where((c) => h.progress.cardState(c.id) != null).length, 1);
  });

  testWidgets('practice keyboard: digit answers, arrows move, F flags', (
    tester,
  ) async {
    await setPhoneViewport(tester, size: const Size(1024, 900));
    await pumpApp(tester, initialLocation: '/practice/mixed/run');
    expect(find.text('Q 1/25'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(find.text('Flagged for review'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Q 2/25'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Q 1/25'), findsOneWidget);
    expect(find.text('Flagged for review'), findsOneWidget);
  });

  testWidgets('first-run intro shows once and stays dismissed', (tester) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    expect(find.byKey(const ValueKey('intro-card')), findsOneWidget);
    await tapKey(tester, 'dismiss-intro');
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    expect(h.progress.introDismissed, isTrue);
  });

  testWidgets('continue card shows streak and today after studying', (
    tester,
  ) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    expect(find.byKey(const ValueKey('streak')), findsNothing);
    final t = h.content.topics.first;
    h.progress.markSectionRead(t.id, t.sections.first.id);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('streak')), findsOneWidget);
    expect(find.text('Today: 1 section'), findsOneWidget);
  });

  testWidgets('multi-select questions show how many to pick', (tester) async {
    final h = await pumpApp(tester);
    final q = h.content.allQuestions.firstWhere(
      (q) => q.type == QuestionType.multi,
    );
    final need = q.options.where((o) => o.correct).length;
    final p = PresentedQuestion(q, q.options);
    Future<void> show(Set<String> selected, {bool interactive = true}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuestionView(
                  presented: p,
                  selected: selected,
                  revealed: false,
                  onChanged: interactive ? (_) {} : null,
                ),
              ),
            ),
          ),
        );
    await show({q.options.first.id});
    expect(find.text('Selected 1 of $need'), findsOneWidget);
    // Read-only views (attempt review) don't show it.
    await show({q.options.first.id}, interactive: false);
    expect(find.byKey(const ValueKey('multi-count')), findsNothing);
  });
}
