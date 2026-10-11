import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../content/models.dart';
import '../engine/clock.dart';
import '../engine/flashcards.dart' as fc;
import '../progress/progress_store.dart';
import '../widgets/page_body.dart';

/// S10 — overall and per-topic progress, practice history, reset.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentBundle>();
    final progress = context.watch<ProgressStore>();
    final now = context.read<Clock>().now();
    final textTheme = Theme.of(context).textTheme;

    final allCards = content.topics.expand((t) => t.flashcards).toList();
    final complete = content.topics.where(progress.topicComplete).length;
    final passed = content.topics.where((t) => progress.quizPassed(t.id)).length;
    final history = progress.practiceHistory.take(10).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: PageList(children: [
        Row(children: [
          _Stat(label: 'Topics complete', value: '$complete/${content.topics.length}'),
          _Stat(label: 'Cards mastered', value: '${progress.masteredCount(allCards)}/${allCards.length}'),
          _Stat(label: 'Quizzes passed', value: '$passed/${content.topics.length}'),
        ]),
        const SizedBox(height: 16),
        Text('Topics', style: textTheme.titleMedium),
        for (final t in content.topics)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              title: Text(t.title),
              subtitle: Text(
                'Notes ${(progress.readCount(t) * 100 / t.sections.length).round()}% · '
                '${fc.dueCount(t.flashcards, progress.cardStates, now)} cards due · '
                'Best quiz ${progress.quizStats(t.id)?.bestPct.toString() ?? '–'}%'
                '${progress.lastActivity(t) == null ? '' : '\nLast activity ${formatDate(progress.lastActivity(t)!)}'}',
              ),
              isThreeLine: progress.lastActivity(t) != null,
              onTap: () => context.go('/topic/${t.id}'),
            ),
          ),
        const SizedBox(height: 16),
        Text('Practice history', style: textTheme.titleMedium),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No practice tests taken yet.', style: textTheme.bodyMedium),
          )
        else
          for (final r in history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(content.practiceTest(r.testId)?.title ?? r.testId),
              subtitle: Text('${formatDate(r.at)} · ${r.durationSec ~/ 60} min'),
              trailing: Text('${r.pct}%', style: textTheme.titleMedium),
            ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const ValueKey('reset-progress'),
          style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Reset progress'),
          onPressed: () => _confirmReset(context, progress),
        ),
        const SizedBox(height: 4),
        Text('Export/import of progress is planned for v1.1.',
            style: textTheme.bodySmall),
      ]),
    );
  }

  Future<void> _confirmReset(BuildContext context, ProgressStore progress) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
            'This clears notes read, flashcard schedules, quiz scores and '
            'practice history on this device. It cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              key: const ValueKey('confirm-reset'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) await progress.resetProgress();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Text(value, style: textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(label, style: textTheme.labelSmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
