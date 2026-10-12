import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/ads/frequency_cap.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/clock.dart';
import 'package:k8_study/engine/flashcards.dart';
import 'package:k8_study/engine/practice.dart';
import 'package:k8_study/engine/quiz.dart';
import 'package:k8_study/progress/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixedClock implements Clock {
  FixedClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}

Future<ProgressStore> store([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return ProgressStore(
    await SharedPreferences.getInstance(),
    clock: FixedClock(DateTime(2026, 10, 11, 12)),
  );
}

void main() {
  test('persists across instances', () async {
    final a = await store();
    a.markSectionRead('ns', 'ns-a');
    a.setCardState('ns-fc-1', CardState(box: 3, dueAt: DateTime(2026, 10, 20)));
    a.recordQuiz('ns', 70, {'ns-q-1'});
    a.recordPractice(
      PracticeRecord(
        testId: 'mixed',
        pct: 60,
        perDomain: {'cluster-arch': const DomainScore(3, 5)},
        durationSec: 90,
        at: DateTime(2026, 10, 11),
      ),
    );

    final b = ProgressStore(await SharedPreferences.getInstance());
    expect(b.readSections('ns'), {'ns-a'});
    expect(b.cardState('ns-fc-1')!.box, 3);
    expect(b.quizStats('ns')!.bestPct, 70);
    expect(b.quizStats('ns')!.missed, ['ns-q-1']);
    expect(b.practiceHistory.single.perDomain['cluster-arch']!.correct, 3);
  });

  test('best score keeps the max; retry-missed runs do not count', () async {
    final s = await store();
    s.recordQuiz('t', 90, {});
    s.recordQuiz('t', 60, {'q1', 'q2'});
    expect(s.quizStats('t')!.bestPct, 90);
    expect(s.quizStats('t')!.lastPct, 60);
    expect(s.quizStats('t')!.attempts, 2);
    s.recordRetryMissed('t', {'q2'});
    expect(s.quizStats('t')!.attempts, 2);
    expect(s.quizStats('t')!.bestPct, 90);
    expect(s.quizStats('t')!.missed, ['q2']);
  });

  test('corrupt JSON in one key resets only that key', () async {
    final s = await store({
      StorageKeys.notes: '{not json',
      StorageKeys.quiz: '{"t":{"attempts":1,"bestPct":80,"lastPct":80,"lastAt":"2026-10-01T00:00:00.000"}}',
    });
    expect(s.readSections('t'), isEmpty);
    expect(s.quizStats('t')!.bestPct, 80);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.notes), isNull);
    expect(prefs.getInt(StorageKeys.schema), schemaVersion);
  });

  test('wrong-shaped data is also treated as corrupt', () async {
    final s = await store({StorageKeys.cards: '{"c":{"box":"x"}}'});
    expect(s.cardStates, isEmpty);
  });

  test('reset clears progress but keeps settings', () async {
    final s = await store();
    s.markSectionRead('t', 'x');
    s.practiceTimerOn = false;
    await s.resetProgress();
    expect(s.readSections('t'), isEmpty);
    expect(s.practiceTimerOn, isFalse);
    final reloaded = ProgressStore(await SharedPreferences.getInstance());
    expect(reloaded.readSections('t'), isEmpty);
    expect(reloaded.practiceTimerOn, isFalse);
  });

  test('history keeps the newest 50', () async {
    final s = await store();
    for (var i = 0; i < 55; i++) {
      s.recordPractice(
        PracticeRecord(
          testId: 'mixed',
          pct: i,
          perDomain: const {},
          durationSec: 1,
          at: DateTime(2026, 10, 11),
        ),
      );
    }
    expect(s.practiceHistory.length, maxPracticeHistory);
    expect(s.practiceHistory.first.pct, 54);
  });

  group('interstitial frequency cap', () {
    test('at most 1 per 3 completions and 1 per 10 minutes', () async {
      final s = await store();
      final t0 = DateTime(2026, 10, 11, 12);
      expect(registerCompletionAndCheck(s, t0), isFalse);
      expect(registerCompletionAndCheck(s, t0), isFalse);
      expect(registerCompletionAndCheck(s, t0), isTrue); // 3rd
      // Three more completions, but within 10 minutes → blocked.
      final t1 = t0.add(const Duration(minutes: 5));
      expect(registerCompletionAndCheck(s, t1), isFalse);
      expect(registerCompletionAndCheck(s, t1), isFalse);
      expect(registerCompletionAndCheck(s, t1), isFalse);
      // After 10 minutes the next completion may show one.
      expect(registerCompletionAndCheck(s, t0.add(minInterval)), isTrue);
    });

    test('cap state persists', () async {
      final s = await store();
      registerCompletionAndCheck(s, DateTime(2026, 10, 11));
      final reloaded = ProgressStore(await SharedPreferences.getInstance());
      expect(reloaded.adCapState.completionsSinceAd, 1);
    });
  });

  test('backup round-trips and rejects foreign data', () async {
    final a = await store();
    a.markSectionRead('t', 'x');
    a.recordQuiz('t', 85, {'q1'});
    final backup = a.exportJson();

    final b = await store();
    expect(b.readSections('t'), isEmpty);
    await b.importJson(backup);
    expect(b.readSections('t'), {'x'});
    expect(b.quizStats('t')!.bestPct, 85);

    await expectLater(
      b.importJson('{"app":"other","data":{}}'),
      throwsFormatException,
    );
    await expectLater(b.importJson('not json'), throwsFormatException);
    // Valid wrapper, damaged payload: rejected before anything is written.
    await expectLater(
      b.importJson(
        '{"app":"k8-study","schema":1,"data":{"k8s.quiz":{"t":{"attempts":"x"}}}}',
      ),
      throwsFormatException,
    );
    await expectLater(
      b.importJson('{"app":"k8-study","schema":"1","data":{}}'),
      throwsFormatException,
    );
    expect(b.quizStats('t')!.bestPct, 85);
    expect(b.readSections('t'), {'x'}, reason: 'failed import changes nothing');
  });

  test('daily activity and streak', () async {
    SharedPreferences.setMockInitialValues({});
    final clock = FixedClock(DateTime(2026, 10, 10, 9));
    final s = ProgressStore(
      await SharedPreferences.getInstance(),
      clock: clock,
    );
    expect(s.streak, 0);
    s.markSectionRead('t', 'a');
    s.setCardState('c', CardState(box: 2, dueAt: DateTime(2026, 10, 11)));
    expect(s.today, {'sections': 1, 'cards': 1});
    expect(s.streak, 1);
    clock.t = DateTime(2026, 10, 11, 9);
    expect(s.streak, 1, reason: 'yesterday counts until today has activity');
    expect(s.today, isEmpty);
    s.markSectionRead('t', 'b');
    expect(s.streak, 2);
    clock.t = DateTime(2026, 10, 13, 9);
    expect(s.streak, 0, reason: 'a missed day breaks the streak');
  });

  test('confidence and review schedule are recorded per answer', () async {
    final p = await store();
    final q = Question(
      id: 'q1',
      topicId: 't',
      type: QuestionType.single,
      stem: 'stem',
      options: const [
        AnswerOption(id: 'a', text: 'A', correct: true, explanation: 'x'),
        AnswerOption(id: 'b', text: 'B', correct: false, explanation: 'y'),
      ],
      sourceUrl: 'https://kubernetes.io/docs/',
      difficulty: 1,
    );
    QuizAttempt run(String pick, {required bool sure}) =>
        QuizAttempt([PresentedQuestion(q, q.options)])
          ..answer(q.id, {pick}, sure: sure);

    // Right but unsure: not solid, due tomorrow.
    p.recordAnswers(run('a', sure: false));
    var s = p.answerStats('q1')!;
    expect(s.lastCorrect, isTrue);
    expect(s.solid, isFalse);
    expect(s.isDue(DateTime(2026, 10, 11)), isFalse);
    expect(s.isDue(DateTime(2026, 10, 12)), isTrue);

    // Wrong: due today. Survives a reload.
    p.recordAnswers(run('b', sure: true));
    final b = ProgressStore(
      await SharedPreferences.getInstance(),
      clock: p.clock,
    );
    s = b.answerStats('q1')!;
    expect(s.lastSure, isTrue);
    expect(s.review!.box, 1);
    expect(s.isDue(DateTime(2026, 10, 11)), isTrue);
  });

  test('answers saved before the schedule: wrong ones are due', () async {
    final p = await store({
      StorageKeys.answers: jsonEncode({
        'wrong': {'n': 1, 'c': 0, 'last': false, 'at': '2026-10-01T10:00:00'},
        'right': {'n': 1, 'c': 1, 'last': true, 'at': '2026-10-01T10:00:00'},
      }),
    });
    final now = DateTime(2026, 10, 11);
    expect(p.answerStats('wrong')!.isDue(now), isTrue);
    expect(p.answerStats('wrong')!.lastSure, isTrue);
    expect(p.answerStats('right')!.review, isNull);
  });
}
