import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/engine/question_review.dart';

void main() {
  final now = DateTime(2026, 10, 12, 15);
  final today = DateTime(2026, 10, 12);

  test('wrong: box 1, due today', () {
    final s = nextSlot(null, correct: false, sure: true, now: now)!;
    expect(s.box, 1);
    expect(s.dueAt, today);
    expect(s.isDue(now), isTrue);
  });

  test('right but unsure: same box, due tomorrow', () {
    final fresh = nextSlot(null, correct: true, sure: false, now: now)!;
    expect(fresh.box, 1);
    expect(fresh.dueAt, DateTime(2026, 10, 13));
    final prev = ReviewSlot(box: 3, dueAt: today);
    final s = nextSlot(prev, correct: true, sure: false, now: now)!;
    expect(s.box, 3);
    expect(s.dueAt, DateTime(2026, 10, 13));
  });

  test('right and sure: never-scheduled stays unscheduled', () {
    expect(nextSlot(null, correct: true, sure: true, now: now), isNull);
  });

  test('right and sure: climbs the Leitner intervals', () {
    var slot = ReviewSlot(box: 1, dueAt: today);
    final gaps = <int>[];
    for (var i = 0; i < 5; i++) {
      slot = nextSlot(slot, correct: true, sure: true, now: now)!;
      gaps.add(slot.dueAt.difference(today).inDays);
    }
    expect(gaps, [1, 3, 7, 14, 30]);
    expect(slot.box, 5);
  });
}
