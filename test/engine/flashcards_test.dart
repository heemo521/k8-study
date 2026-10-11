import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/flashcards.dart';

Flashcard card(String id) =>
    Flashcard(id: id, topicId: 't', front: 'f', back: 'b', sourceUrl: 'u');

void main() {
  final now = DateTime(2026, 10, 11, 15, 30);

  group('Leitner transitions', () {
    test('new card: Got it → box 2, due +1 day', () {
      final s = gotIt(null, now);
      expect(s.box, 2);
      expect(s.dueAt, DateTime(2026, 10, 12));
    });

    test('box intervals 1→2 (+1d), 2→3 (+3d), 3→4 (+7d), 4→5 (+14d), 5→5 (+30d)',
        () {
      final expected = {1: (2, 1), 2: (3, 3), 3: (4, 7), 4: (5, 14), 5: (5, 30)};
      expected.forEach((box, outcome) {
        final s = gotIt(CardState(box: box, dueAt: now), now);
        expect(s.box, outcome.$1, reason: 'from box $box');
        expect(s.dueAt, DateTime(2026, 10, 11).add(Duration(days: outcome.$2)),
            reason: 'from box $box');
      });
    });

    test('Again → box 1, due today', () {
      final s = again(now);
      expect(s.box, 1);
      expect(s.dueAt, DateTime(2026, 10, 11));
      expect(s.isDue(now), isTrue);
    });

    test('mastered means box ≥ 4', () {
      expect(CardState(box: 3, dueAt: now).mastered, isFalse);
      expect(CardState(box: 4, dueAt: now).mastered, isTrue);
    });

    test('due compares calendar dates, not milliseconds', () {
      final s = CardState(box: 2, dueAt: DateTime(2026, 10, 12));
      expect(s.isDue(DateTime(2026, 10, 11, 23, 59)), isFalse);
      expect(s.isDue(DateTime(2026, 10, 12, 0, 1)), isTrue);
    });

    test('JSON round-trip and bad box rejected', () {
      final s = CardState(box: 3, dueAt: DateTime(2026, 10, 20), lastReviewedAt: now);
      final back = CardState.fromJson(s.toJson());
      expect(back.box, 3);
      expect(back.dueAt, DateTime(2026, 10, 20));
      expect(() => CardState.fromJson({'box': 9, 'dueAt': '2026-10-20'}),
          throwsFormatException);
    });
  });

  group('buildSession', () {
    test('due cards (oldest first) then new cards, capped', () {
      final cards = [for (var i = 0; i < 30; i++) card('c$i')];
      final states = <String, CardState>{
        // 3 due, 1 not yet due.
        'c0': CardState(box: 2, dueAt: DateTime(2026, 10, 9)),
        'c1': CardState(box: 2, dueAt: DateTime(2026, 10, 1)),
        'c2': CardState(box: 3, dueAt: DateTime(2026, 10, 11)),
        'c3': CardState(box: 3, dueAt: DateTime(2026, 10, 30)),
      };
      final session = buildSession(
          cards: cards, states: states, now: now, random: Random(1));
      expect(session.length, sessionCap);
      expect(session.take(3).map((c) => c.id).toSet(), {'c0', 'c1', 'c2'});
      expect(session.map((c) => c.id), isNot(contains('c3')));
      expect(session.skip(3).every((c) => states[c.id] == null), isTrue);
    });

    test('nothing due and nothing new → empty session', () {
      final cards = [card('a')];
      final states = {'a': CardState(box: 5, dueAt: DateTime(2026, 11, 1))};
      expect(
          buildSession(cards: cards, states: states, now: now, random: Random(1)),
          isEmpty);
      expect(nextDueDate(cards, states, now), DateTime(2026, 11, 1));
    });
  });

  group('FlashcardSession', () {
    test('Again re-queues a card once per session', () {
      final s = FlashcardSession(cards: [card('a'), card('b')]);
      s.answer(knewIt: false, previous: null, now: now); // a → requeued
      s.answer(knewIt: true, previous: null, now: now); // b
      expect(s.current.id, 'a');
      s.answer(knewIt: false, previous: null, now: now); // a again, not requeued
      expect(s.isDone, isTrue);
      expect(s.reviewed, 3);
      expect(s.gotItCount, 1);
    });

    test('practice mode returns no state changes', () {
      final s = FlashcardSession(cards: [card('a')], practiceMode: true);
      expect(s.answer(knewIt: true, previous: null, now: now), isNull);
    });
  });
}
