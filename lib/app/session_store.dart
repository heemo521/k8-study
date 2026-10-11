import '../engine/practice.dart';
import '../engine/quiz.dart';

/// In-memory hand-off of a finished attempt to its results screen. Not
/// persisted: reloading a results URL falls back to the topic/practice page.
class QuizResult {
  QuizResult({
    required this.topicId,
    required this.attempt,
    required this.retryMissed,
  });

  final String topicId;
  final QuizAttempt attempt;

  /// "Retry missed" runs don't count toward best score.
  final bool retryMissed;
}

class PracticeResult {
  PracticeResult({
    required this.testId,
    required this.attempt,
    required this.duration,
    required this.breakdown,
  });

  final String testId;
  final QuizAttempt attempt;
  final Duration duration;
  final Map<String, DomainScore> breakdown;
}

class SessionStore {
  QuizResult? lastQuiz;
  PracticeResult? lastPractice;
}
