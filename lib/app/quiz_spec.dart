/// What a quiz run draws from: one topic, or a cross-topic review.
sealed class QuizSpec {
  const QuizSpec();

  /// Where the results screen lives.
  String get resultPath;

  /// Where "leave"/"back" goes.
  String get exitPath;

  /// URL that starts this same quiz again.
  String get startPath;
}

class TopicQuizSpec extends QuizSpec {
  const TopicQuizSpec(this.topicId, {this.retryMissed = false});

  final String topicId;

  /// Only questions missed last time; doesn't count toward best score.
  final bool retryMissed;

  @override
  String get resultPath => '/topic/$topicId/quiz/result';
  @override
  String get exitPath => '/topic/$topicId';
  @override
  String get startPath =>
      '/topic/$topicId/quiz${retryMissed ? '?mode=missed' : ''}';
}

/// kind: `missed` (last answer wrong), `competency` or `domain` (with [id]).
class ReviewQuizSpec extends QuizSpec {
  const ReviewQuizSpec(this.kind, [this.id]);

  final String kind;
  final String? id;

  @override
  String get resultPath => '/progress/review/result';
  @override
  String get exitPath => '/progress';
  @override
  String get startPath =>
      '/progress/review?kind=$kind${id == null ? '' : '&id=$id'}';
}
