import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app/session_store.dart';
import '../content/models.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/question_view.dart';

/// S9 — score, per-domain breakdown, weak spots and review.
class PracticeResultScreen extends StatelessWidget {
  const PracticeResultScreen({super.key, required this.testId});

  final String testId;

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentBundle>();
    final result = context.read<SessionStore>().lastPractice;
    final test = content.practiceTest(testId);
    if (test == null || result == null || result.testId != testId) {
      return const NotFoundView(
        message: 'No recent practice result to show.',
        backTo: '/practice',
      );
    }
    final attempt = result.attempt;
    final textTheme = Theme.of(context).textTheme;
    final minutes = result.duration.inMinutes;
    final seconds = result.duration.inSeconds % 60;

    // Topics with at least one miss, worst first.
    final missesByTopic = <String, int>{};
    for (final p in attempt.questions) {
      if (!attempt.correct(p)) {
        missesByTopic[p.question.topicId] =
            (missesByTopic[p.question.topicId] ?? 0) + 1;
      }
    }
    final weak = missesByTopic.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: Text(test.title),
        leading: BackButton(onPressed: () => context.go('/practice')),
      ),
      body: PageList(
        children: [
          Text(
            '${attempt.percent}%',
            key: const ValueKey('practice-score'),
            style: textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            '${attempt.correctCount} of ${attempt.questions.length} correct · '
            '${minutes}m ${seconds}s',
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text('By CKA domain', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final e in result.breakdown.entries)
            Padding(
              key: ValueKey('breakdown-${e.key}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${content.domain(e.key)?.title ?? e.key}: '
                    '${e.value.correct}/${e.value.total} (${e.value.percent}%)',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: e.value.total == 0
                        ? 0
                        : e.value.correct / e.value.total,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          if (weak.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Weak spots', style: textTheme.titleMedium),
            for (final e in weak)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(content.topic(e.key)?.title ?? e.key),
                subtitle: Text('${e.value} missed'),
                trailing: const Text('Review notes'),
                onTap: () => context.go('/topic/${e.key}/notes'),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (attempt.missedIds.isNotEmpty)
                FilledButton.icon(
                  key: const ValueKey('review-missed-after-test'),
                  onPressed: () => context.go('/progress/review?kind=missed'),
                  icon: const Icon(Icons.replay),
                  label: const Text('Review missed'),
                ),
              OutlinedButton(
                onPressed: () => context.go('/practice/$testId/run'),
                child: const Text('Retake'),
              ),
              TextButton(
                onPressed: () => context.go('/progress'),
                child: const Text('See my gaps'),
              ),
            ],
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
