import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app/session_store.dart';
import '../content/models.dart';
import '../engine/quiz.dart';
import '../progress/progress_store.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/question_view.dart';

/// S6 — score, review and retry.
class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    final topic = context.read<ContentBundle>().topic(topicId);
    final result = context.read<SessionStore>().lastQuiz;
    if (topic == null || result == null || result.topicId != topicId) {
      return NotFoundView(
        message: 'No recent quiz result to show.',
        backTo: topic == null ? '/' : '/topic/$topicId',
      );
    }
    final attempt = result.attempt;
    final stats = context.watch<ProgressStore>().quizStats(topicId);
    final textTheme = Theme.of(context).textTheme;
    final pct = attempt.percent;
    final mastered = pct >= masteryPercent;
    final hasMissed = (stats?.missed ?? const []).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(result.retryMissed ? 'Retry results' : 'Quiz results'),
        leading: BackButton(onPressed: () => context.go('/topic/$topicId')),
      ),
      body: PageList(children: [
        Text('$pct%',
            key: const ValueKey('quiz-score'),
            style: textTheme.displayMedium,
            textAlign: TextAlign.center),
        Text('${attempt.correctCount} of ${attempt.questions.length} correct',
            style: textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        if (result.retryMissed)
          Text('Retry runs don’t change your best score.',
              style: textTheme.bodySmall, textAlign: TextAlign.center)
        else
          Text(
            mastered
                ? 'Topic mastered (≥ $masteryPercent%)'
                : 'Topic mastery needs $masteryPercent% — keep going',
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        if (stats != null)
          Text('Best so far: ${stats.bestPct}%',
              style: textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('The mastery mark is this app’s own bar, not a CKA pass mark.',
            style: textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const ValueKey('retry-all'),
              onPressed: () => context.go('/topic/$topicId/quiz'),
              child: const Text('Retry all'),
            ),
            OutlinedButton(
              key: const ValueKey('retry-missed'),
              onPressed: hasMissed
                  ? () => context.go('/topic/$topicId/quiz?mode=missed')
                  : null,
              child: const Text('Retry missed'),
            ),
            TextButton(
              onPressed: () => context.go('/topic/$topicId'),
              child: const Text('Back to topic'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Review', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        AttemptReview(attempt: attempt),
      ]),
    );
  }
}
