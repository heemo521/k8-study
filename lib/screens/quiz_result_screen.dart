import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app/quiz_spec.dart';
import '../app/session_store.dart';
import '../content/models.dart';
import '../engine/quiz.dart';
import '../progress/insights.dart';
import '../progress/progress_store.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/question_view.dart';

/// S6 — score, review, retry, and what to do next.
class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key, this.topicId});

  /// Null for review quizzes.
  final String? topicId;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentBundle>();
    final result = context.read<SessionStore>().lastQuiz;
    final spec = result?.spec;
    final matches = switch (spec) {
      TopicQuizSpec(topicId: final id) => id == topicId,
      ReviewQuizSpec() => topicId == null,
      null => false,
    };
    if (result == null || !matches) {
      return NotFoundView(
        message: 'No recent quiz result to show.',
        backTo: topicId == null ? '/progress' : '/topic/$topicId',
      );
    }
    final progress = context.watch<ProgressStore>();
    final attempt = result.attempt;
    final textTheme = Theme.of(context).textTheme;
    final pct = attempt.percent;

    final children = <Widget>[
      Text(
        '$pct%',
        key: const ValueKey('quiz-score'),
        style: textTheme.displayMedium,
        textAlign: TextAlign.center,
      ),
      Text(
        '${attempt.correctCount} of ${attempt.questions.length} correct',
        style: textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
    ];
    final actions = <Widget>[];

    switch (spec!) {
      case TopicQuizSpec(:final topicId, :final retryMissed):
        final topic = content.topic(topicId);
        // e.g. results for a topic of a subject that's no longer selected.
        if (topic == null) {
          return const NotFoundView(message: 'No recent quiz result to show.');
        }
        final stats = progress.quizStats(topicId);
        final mastered = (stats?.bestPct ?? 0) >= masteryPercent;
        children.addAll([
          if (retryMissed)
            Text(
              'Retry runs don’t change your best score.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            )
          else
            Text(
              pct >= masteryPercent
                  ? 'Topic mastered (≥ $masteryPercent%)'
                  : 'Topic mastery needs $masteryPercent% — keep going',
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          if (stats != null)
            Text(
              'Best so far: ${stats.bestPct}%',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 4),
          Text(
            'The mastery mark is this app’s own bar, not an exam pass mark.',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ]);
        final next = mastered ? nextAction(content, progress) : null;
        actions.addAll([
          if (next != null && next.topic.id != topicId)
            FilledButton.icon(
              key: const ValueKey('next-topic'),
              onPressed: () => context.go('/topic/${next.topic.id}'),
              icon: const Icon(Icons.arrow_forward),
              label: Text('Next: ${next.topic.title}'),
            ),
          OutlinedButton(
            key: const ValueKey('retry-all'),
            onPressed: () => context.go('/topic/$topicId/quiz'),
            child: const Text('Retry all'),
          ),
          OutlinedButton(
            key: const ValueKey('retry-missed'),
            onPressed:
                (stats?.missed ?? const []).any(
                  (id) => topic.questions.any((q) => q.id == id),
                )
                ? () => context.go('/topic/$topicId/quiz?mode=missed')
                : null,
            child: const Text('Retry missed'),
          ),
          if (attempt.missedIds.isNotEmpty)
            TextButton(
              onPressed: () => context.go('/topic/$topicId/notes'),
              child: const Text('Re-read notes'),
            ),
          TextButton(
            onPressed: () => context.go('/topic/${topic.id}'),
            child: const Text('Back to topic'),
          ),
        ]);
      case ReviewQuizSpec():
        children.add(
          Text(
            'Answers count toward your gap analysis.',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        );
        actions.addAll([
          FilledButton(
            key: const ValueKey('review-again'),
            onPressed: () => context.go(spec.startPath),
            child: const Text('Review again'),
          ),
          OutlinedButton(
            onPressed: () => context.go('/progress'),
            child: const Text('Back to Progress'),
          ),
        ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (spec) {
          TopicQuizSpec(retryMissed: true) => 'Retry results',
          TopicQuizSpec() => 'Quiz results',
          ReviewQuizSpec() => 'Review results',
        }),
        leading: BackButton(onPressed: () => context.go(spec.exitPath)),
      ),
      body: PageList(
        children: [
          ...children,
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
          const SizedBox(height: 16),
          Text('Review', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          AttemptReview(attempt: attempt),
        ],
      ),
    );
  }
}
