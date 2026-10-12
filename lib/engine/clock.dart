/// Injectable time source so engines are deterministic in tests.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Local calendar date (midnight) for [t]; flashcard due dates compare on this.
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
