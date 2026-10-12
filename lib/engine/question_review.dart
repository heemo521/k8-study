/// Spaced review of questions (spec §15.2). Questions enter the schedule
/// when answered wrong or unsure, then follow the flashcard Leitner
/// intervals until answered right *and* sure.
library;

import 'dart:math';

import 'clock.dart';
import 'flashcards.dart' show leitnerIntervalDays, maxBox;

/// Where a question sits in the review schedule.
class ReviewSlot {
  const ReviewSlot({required this.box, required this.dueAt});

  /// 1..5, as for flashcards.
  final int box;

  /// Local calendar date the question is next due.
  final DateTime dueAt;

  bool isDue(DateTime now) => !dateOnly(dueAt).isAfter(dateOnly(now));
}

/// The schedule after one answer.
///
/// - Wrong: box 1, due today (like a flashcard's "Again").
/// - Right but unsure: same box, due tomorrow — a guess isn't knowledge.
/// - Right and sure: moves up a box like "Got it"; a question that was
///   never scheduled stays unscheduled (null).
ReviewSlot? nextSlot(
  ReviewSlot? prev, {
  required bool correct,
  required bool sure,
  required DateTime now,
}) {
  final today = dateOnly(now);
  if (!correct) return ReviewSlot(box: 1, dueAt: today);
  if (!sure) {
    return ReviewSlot(
      box: prev?.box ?? 1,
      dueAt: today.add(const Duration(days: 1)),
    );
  }
  if (prev == null) return null;
  return ReviewSlot(
    box: min(prev.box + 1, maxBox),
    dueAt: today.add(Duration(days: leitnerIntervalDays[prev.box]!)),
  );
}
