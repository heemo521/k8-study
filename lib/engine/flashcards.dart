/// Leitner flashcard engine, 5 boxes (spec §7.1).
library;

import 'dart:math';

import '../content/models.dart';
import 'clock.dart';

/// Days until next review after "Got it", keyed by the box the card was in.
const leitnerIntervalDays = {1: 1, 2: 3, 3: 7, 4: 14, 5: 30};
const maxBox = 5;
const masteredBox = 4;
const sessionCap = 20;

class CardState {
  const CardState({
    required this.box,
    required this.dueAt,
    this.lastReviewedAt,
  });

  /// 1..5
  final int box;

  /// Local calendar date the card is next due.
  final DateTime dueAt;
  final DateTime? lastReviewedAt;

  bool get mastered => box >= masteredBox;

  bool isDue(DateTime now) => !dateOnly(dueAt).isAfter(dateOnly(now));

  Map<String, dynamic> toJson() => {
        'box': box,
        'dueAt': formatDate(dueAt),
        if (lastReviewedAt != null)
          'lastReviewedAt': lastReviewedAt!.toIso8601String(),
      };

  static CardState fromJson(Map<String, dynamic> json) {
    final box = json['box'];
    final due = DateTime.parse(json['dueAt'] as String);
    final last = json['lastReviewedAt'];
    if (box is! int || box < 1 || box > maxBox) {
      throw FormatException('bad box: $box');
    }
    return CardState(
      box: box,
      dueAt: dateOnly(due),
      lastReviewedAt: last is String ? DateTime.parse(last) : null,
    );
  }
}

/// New state after "Got it". A card with no state is treated as box 1.
CardState gotIt(CardState? state, DateTime now) {
  final box = state?.box ?? 1;
  return CardState(
    box: min(box + 1, maxBox),
    dueAt: dateOnly(now).add(Duration(days: leitnerIntervalDays[box]!)),
    lastReviewedAt: now,
  );
}

/// New state after "Again": back to box 1, due today.
CardState again(DateTime now) =>
    CardState(box: 1, dueAt: dateOnly(now), lastReviewedAt: now);

/// Cards for a session: due cards (oldest due first) then never-seen cards,
/// capped at [cap]; the order within each group is shuffled.
List<Flashcard> buildSession({
  required List<Flashcard> cards,
  required Map<String, CardState> states,
  required DateTime now,
  required Random random,
  int cap = sessionCap,
}) {
  final due = cards
      .where((c) => states[c.id] != null && states[c.id]!.isDue(now))
      .toList()
    ..sort((a, b) => states[a.id]!.dueAt.compareTo(states[b.id]!.dueAt));
  final fresh = cards.where((c) => states[c.id] == null).toList();

  final dueTaken = due.take(cap).toList()..shuffle(random);
  final freshTaken =
      fresh.take(max(0, cap - dueTaken.length)).toList()..shuffle(random);
  return [...dueTaken, ...freshTaken];
}

/// Number of cards that a normal session would include right now.
int dueCount(List<Flashcard> cards, Map<String, CardState> states, DateTime now) =>
    cards
        .where((c) => states[c.id] == null || states[c.id]!.isDue(now))
        .length;

/// Earliest future due date among [cards], or null.
DateTime? nextDueDate(
    List<Flashcard> cards, Map<String, CardState> states, DateTime now) {
  DateTime? next;
  for (final c in cards) {
    final s = states[c.id];
    if (s == null || s.isDue(now)) continue;
    if (next == null || s.dueAt.isBefore(next)) next = s.dueAt;
  }
  return next;
}

/// A running review session. Mutable; pure Dart.
class FlashcardSession {
  FlashcardSession({required List<Flashcard> cards, this.practiceMode = false})
      : _queue = [...cards];

  /// "Practice anyway": reviewing doesn't change box or due date.
  final bool practiceMode;
  final List<Flashcard> _queue;
  final Set<String> _requeued = {};
  int _index = 0;
  int reviewed = 0;
  int gotItCount = 0;

  bool get isDone => _index >= _queue.length;
  Flashcard get current => _queue[_index];
  int get position => _index;
  int get length => _queue.length;
  int get remaining => _queue.length - _index;

  /// Records an answer for the current card and advances.
  /// Returns the new persisted state, or null in practice mode.
  CardState? answer({
    required bool knewIt,
    required CardState? previous,
    required DateTime now,
  }) {
    final card = current;
    reviewed++;
    CardState? next;
    if (knewIt) {
      gotItCount++;
      next = practiceMode ? null : gotIt(previous, now);
    } else {
      next = practiceMode ? null : again(now);
      // Re-queue at the end of this session, at most once.
      if (_requeued.add(card.id)) _queue.add(card);
    }
    _index++;
    return next;
  }
}
