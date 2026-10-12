import '../engine/practice.dart';
import '../engine/quiz.dart';
import 'quiz_spec.dart';

/// In-memory hand-off of a finished attempt to its results screen. Not
/// persisted: reloading a results URL falls back to the topic/practice page.
class QuizResult {
  QuizResult({required this.spec, required this.attempt, this.xpEarned = 0});

  final QuizSpec spec;
  final QuizAttempt attempt;
  final int xpEarned;
}

class PracticeResult {
  PracticeResult({
    required this.testId,
    required this.attempt,
    required this.duration,
    required this.breakdown,
    this.xpEarned = 0,
  });

  final String testId;
  final QuizAttempt attempt;
  final Duration duration;
  final Map<String, DomainScore> breakdown;
  final int xpEarned;
}

class SessionStore {
  QuizResult? lastQuiz;
  PracticeResult? lastPractice;
}
