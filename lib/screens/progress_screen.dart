import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../content/models.dart';
import '../engine/clock.dart';
import '../progress/insights.dart';
import '../progress/progress_store.dart';
import '../widgets/page_body.dart';
import '../widgets/topic_status.dart';

/// S10 — where you stand and where the gaps are: readiness by domain, weakest
/// competencies, topics needing attention, reviews due, history and reset.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _showAllGaps = false;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentBundle>();
    final progress = context.watch<ProgressStore>();
    final now = context.read<Clock>().now();
    final textTheme = Theme.of(context).textTheme;

    final allCards = content.allFlashcards.toList();
    final complete = content.topics.where(progress.topicComplete).length;
    final passed = content.topics
        .where((t) => progress.quizPassed(t.id))
        .length;
    final due = dueCardCount(content, progress, now);
    final missed = missedQuestions(content, progress).length;
    final readiness = domainReadiness(
      content,
      progress,
    ).where((r) => r.hasContent).toList();
    final gaps = competencyGaps(content, progress);
    final openGaps = gaps.where((g) => g.isGap).toList();
    final shownGaps = _showAllGaps ? gaps : openGaps.take(5).toList();
    final weak = weakTopics(content, progress).take(5).toList();
    final history = progress.practiceHistory
        .where((r) => content.practiceTest(r.testId) != null)
        .take(10)
        .toList();
    final answered = progress.answerHistory.keys
        .where((id) => content.question(id) != null)
        .length;

    Widget heading(String text, {String? subtitle}) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(text, style: textTheme.titleMedium),
          ),
          if (subtitle != null) Text(subtitle, style: textTheme.bodySmall),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Progress & gaps')),
      body: PageList(
        children: [
          Row(
            children: [
              _Stat(
                label: 'Topics complete',
                value: '$complete/${content.topics.length}',
              ),
              _Stat(
                label: 'Cards mastered',
                value: '${progress.masteredCount(allCards)}/${allCards.length}',
              ),
              _Stat(
                label: 'Quizzes passed',
                value: '$passed/${content.topics.length}',
              ),
            ],
          ),

          // ---- reviews -------------------------------------------------------
          heading('Review now'),
          if (due == 0 && missed == 0)
            Text(
              'Nothing to review yet. Flashcards come due after you study them, '
              'and questions you get wrong in quizzes appear here.',
              style: textTheme.bodyMedium,
            )
          else
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const ValueKey('review-due-cards'),
                    leading: const Icon(Icons.style_outlined),
                    title: Text(
                      '$due ${due == 1 ? 'flashcard' : 'flashcards'} due',
                    ),
                    subtitle: const Text('Across all topics, 20 at a time'),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: due > 0,
                    onTap: () => context.go('/progress/cards'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('review-missed'),
                    leading: const Icon(Icons.replay),
                    title: Text(
                      '$missed missed ${missed == 1 ? 'question' : 'questions'}',
                    ),
                    subtitle: const Text('Questions you got wrong last time'),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: missed > 0,
                    onTap: () => context.go('/progress/review?kind=missed'),
                  ),
                ],
              ),
            ),

          // ---- readiness by domain ------------------------------------------
          heading(
            content.exam == null
                ? 'Progress by area'
                : '${content.exam!.name} readiness by domain',
            subtitle:
                'Bars show topic progress (notes read and quiz mastery). '
                'Accuracy uses your latest answer to each question.',
          ),
          for (final r in readiness)
            _DomainRow(readiness: r, examName: content.exam?.name),
          for (final d in content.domainsInDisplayOrder.where(
            (d) => d.isExamDomain && content.topicsForDomain(d.id).isEmpty,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${d.title}: no topics yet',
                style: textTheme.bodySmall,
              ),
            ),

          // ---- competency gaps ----------------------------------------------
          heading(
            'Knowledge gaps',
            subtitle: answered == 0
                ? 'Take a quiz or practice test to see which competencies need work.'
                : 'Weakest competencies first: low accuracy, or under half the '
                      'questions answered.',
          ),
          if (shownGaps.isEmpty && answered > 0)
            Text(
              'No open gaps. Every competency is at or above mastery.',
              style: textTheme.bodyMedium,
            ),
          for (final g in shownGaps) _GapTile(gap: g),
          if (gaps.length > openGaps.take(5).length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('toggle-gaps'),
                onPressed: () => setState(() => _showAllGaps = !_showAllGaps),
                child: Text(
                  _showAllGaps
                      ? 'Show only gaps'
                      : 'Show all ${gaps.length} competencies',
                ),
              ),
            ),

          // ---- weak topics ----------------------------------------------------
          if (weak.isNotEmpty) ...[
            heading(
              'Needs attention',
              subtitle: 'Started but not yet complete',
            ),
            for (final t in weak)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(t.title),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TopicStepRow(topic: t),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/topic/${t.id}'),
                ),
              ),
          ],

          // ---- history --------------------------------------------------------
          heading('Practice history'),
          if (history.isEmpty)
            Text('No practice tests taken yet.', style: textTheme.bodyMedium)
          else
            for (final r in history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(content.practiceTest(r.testId)!.title),
                subtitle: Text(
                  '${formatDate(r.at)} · ${r.durationSec ~/ 60} min',
                ),
                trailing: Text('${r.pct}%', style: textTheme.titleMedium),
              ),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('reset-progress'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Reset progress'),
            onPressed: () => _confirmReset(context, progress),
          ),
          const SizedBox(height: 4),
          Text(
            'Progress is stored only on this device. Back it up to move it '
            'to another browser or device.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('export-progress'),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Copy backup'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: progress.exportJson()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Backup copied. Paste it somewhere safe.',
                        ),
                      ),
                    );
                  }
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('import-progress'),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Restore backup'),
                onPressed: () => _restore(context, progress),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, ProgressStore progress) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup'),
        content: TextField(
          key: const ValueKey('backup-field'),
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Paste a backup copied from K8 Study',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('confirm-restore'),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Replace my progress'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    try {
      await progress.importJson(text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Progress restored.')));
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: ${e.message}')));
      }
    }
  }

  Future<void> _confirmReset(
    BuildContext context,
    ProgressStore progress,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
          'This clears notes read, flashcard schedules, quiz scores, answer '
          'history and practice history on this device, for every subject. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('confirm-reset'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await progress.resetProgress();
  }
}

class _DomainRow extends StatelessWidget {
  const _DomainRow({required this.readiness, required this.examName});

  final DomainReadiness readiness;
  final String? examName;

  @override
  Widget build(BuildContext context) {
    final r = readiness;
    final textTheme = Theme.of(context).textTheme;
    final acc = r.accuracy;
    return Card(
      key: ValueKey('readiness-${r.domain.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: r.questionsTotal == 0
            ? null
            : () =>
                  context.go('/progress/review?kind=domain&id=${r.domain.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.domain.title, style: textTheme.titleSmall),
                  ),
                  if (r.domain.weightPercent != null)
                    Text(
                      '${r.domain.weightPercent}%',
                      style: textTheme.labelMedium,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: r.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                semanticsLabel: '${r.domain.title} progress',
              ),
              const SizedBox(height: 6),
              Text(
                '${r.topicsComplete}/${r.topics.length} topics complete · '
                '${acc == null ? 'no questions answered yet' : '${(acc * 100).round()}% accuracy on ${r.questionsSeen}/${r.questionsTotal} questions'}',
                style: textTheme.bodySmall,
              ),
              if (r.questionsTotal > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Review this domain ›',
                    style: textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GapTile extends StatelessWidget {
  const _GapTile({required this.gap});

  final CompetencyGap gap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final acc = gap.accuracy;
    final state = acc == null
        ? ProgressState.todo
        : (gap.isGap ? ProgressState.weak : ProgressState.done);
    return Card(
      key: ValueKey('gap-${gap.competency.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(gap.competency.text, style: textTheme.bodyMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              StepChip(
                label: acc == null
                    ? 'Not tested'
                    : '${(acc * 100).round()}% right',
                state: state,
              ),
              StepChip(
                label: '${gap.seen}/${gap.total} answered',
                state: gap.seen * 2 < gap.total
                    ? ProgressState.partial
                    : ProgressState.done,
              ),
              Text(
                gap.domain.title,
                style: textTheme.labelSmall?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.play_circle_outline),
        onTap: () => context.go(
          '/progress/review?kind=competency&id=${gap.competency.id}',
        ),
      ),
    );
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
          child: Column(
            children: [
              Text(value, style: textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
