import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/clock.dart';
import 'package:k8_study/engine/flashcards.dart';
import 'package:k8_study/engine/quiz.dart';
import 'package:k8_study/progress/progress_store.dart';
import 'package:k8_study/progress/rewards.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixedClock implements Clock {
  FixedClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}

Question question(String id) => Question(
  id: id,
  topicId: 't',
  type: QuestionType.single,
  stem: 'Q',
  options: const [
    AnswerOption(id: 'a', text: 'A', correct: true, explanation: ''),
    AnswerOption(id: 'b', text: 'B', correct: false, explanation: ''),
  ],
  sourceUrl: 'https://example.com',
  difficulty: 1,
);

QuizAttempt attempt(Map<String, String> answers) {
  final a = QuizAttempt([
    for (final id in answers.keys)
      PresentedQuestion(question(id), question(id).options),
  ]);
  for (final e in answers.entries) {
    if (e.value.isNotEmpty) a.answer(e.key, {e.value});
  }
  return a;
}

void main() {
  late FixedClock clock;

  Future<ProgressStore> store([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    clock = FixedClock(DateTime(2026, 10, 11, 12));
    return ProgressStore(await SharedPreferences.getInstance(), clock: clock);
  }

  test('levels need 100, 200, 300… XP', () {
    expect(LevelInfo.fromXp(0).level, 1);
    expect(LevelInfo.fromXp(99).level, 1);
    expect(LevelInfo.fromXp(100).level, 2);
    final l = LevelInfo.fromXp(250);
    expect([l.level, l.into, l.needed], [2, 150, 200]);
    expect(LevelInfo.fromXp(300).level, 3);
  });

  test('XP for notes, cards and answers', () async {
    final s = await store();
    expect(s.xp, 0);
    s.markSectionRead('t', 'a');
    s.markSectionRead('t', 'a'); // already read: no XP
    expect(s.xp, Xp.sectionRead);
    s.setCardState('c', CardState(box: 2, dueAt: DateTime(2026, 10, 12)));
    expect(s.xp, Xp.sectionRead + Xp.cardReviewed);
    final earned = s.recordAnswers(
      attempt({'q1': 'a', 'q2': 'b', 'q3': ''}), // right, wrong, skipped
    );
    expect(earned, Xp.correctAnswer + Xp.wrongAnswer);
    expect(s.xp, Xp.sectionRead + Xp.cardReviewed + earned);
  });

  test('mastery bonus only the first time a quiz passes', () async {
    final s = await store();
    expect(s.recordQuiz('t', 60, {}), 0);
    expect(s.recordQuiz('t', 90, {}), Xp.quizMastered);
    expect(s.recordQuiz('t', 100, {}), 0);
    expect(s.xp, Xp.quizMastered);
  });

  test(
    'streak survives restarts, breaks on a missed day, keeps best',
    () async {
      final s = await store();
      expect(s.streak, 0);
      for (var d = 0; d < 3; d++) {
        clock.t = DateTime(2026, 10, 11 + d, 9);
        s.markSectionRead('t', 's$d');
      }
      expect(s.streak, 3);
      final again = ProgressStore(
        await SharedPreferences.getInstance(),
        clock: FixedClock(DateTime(2026, 10, 14, 9)),
      );
      expect(again.streak, 3, reason: 'yesterday still counts');
      expect(again.bestStreak, 3);
      clock.t = DateTime(2026, 10, 16, 9);
      expect(s.streak, 0);
      s.markSectionRead('t', 'x');
      expect(s.streak, 1);
      expect(s.bestStreak, 3);
    },
  );

  test('streak keeps counting past the 60-day activity window', () async {
    final s = await store();
    for (var d = 0; d < 70; d++) {
      clock.t = DateTime(2026, 1, 1).add(Duration(days: d, hours: 12));
      s.markSectionRead('t', 's$d');
    }
    expect(s.streak, 70);
  });

  test('existing progress is credited on first load', () async {
    final s = await store({
      StorageKeys.notes: jsonEncode({
        't': ['a', 'b'],
      }),
      StorageKeys.quiz: jsonEncode({
        't': {
          'attempts': 1,
          'bestPct': 90,
          'lastPct': 90,
          'lastAt': '2026-10-10T09:00:00.000',
          'missed': [],
        },
      }),
      StorageKeys.activity: jsonEncode({
        '2026-10-09': {'sections': 1},
        '2026-10-10': {'sections': 1},
      }),
    });
    expect(s.xp, 2 * Xp.sectionRead + Xp.quizMastered);
    expect(s.streak, 2);
  });

  test('backup round-trip and reset', () async {
    final s = await store();
    s.markSectionRead('t', 'a');
    final backup = s.exportJson();
    await s.resetProgress();
    expect(s.xp, 0);
    expect(s.streak, 0);
    await s.importJson(backup);
    expect(s.xp, Xp.sectionRead);
    expect(s.streak, 1);
  });

  test('corrupt rewards fall back to credited progress', () async {
    final s = await store({
      StorageKeys.rewards: '{"xp":"lots"}',
      StorageKeys.notes: jsonEncode({
        't': ['a'],
      }),
    });
    expect(s.xp, Xp.sectionRead);
  });
}
