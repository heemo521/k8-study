import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../content/models.dart';
import '../progress/gap_plan.dart';
import '../progress/progress_store.dart';
import '../widgets/page_body.dart';

/// The gap plan built from an exam: each weak competency with three steps
/// (read, review, pass a targeted quiz), and a re-test of what's still open.
class GapPlanScreen extends StatelessWidget {
  const GapPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentBundle>();
    final progress = context.watch<ProgressStore>();
    final plan = progress.gapPlan(content.subject.id);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gap plan'),
          leading: BackButton(onPressed: () => context.go('/progress')),
        ),
        body: PageList(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.flag_outlined, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'No gap plan yet',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Take a mock exam. Its results show which competencies need '
              'work and build a step-by-step plan to fill them.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('plan-take-exam'),
              onPressed: () => context.go('/practice'),
              child: const Text('Take a mock exam'),
            ),
          ],
        ),
      );
    }

    final items = planStatus(content, progress, plan);
    final fixed = items.where((i) => i.fixed).length;
    final allFixed = items.isNotEmpty && fixed == items.length;
    final test = content.practiceTest(plan.testId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gap plan'),
        leading: BackButton(onPressed: () => context.go('/progress')),
        actions: [
          IconButton(
            key: const ValueKey('plan-discard'),
            tooltip: 'Discard plan',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDiscard(context, content, progress),
          ),
        ],
      ),
      body: PageList(
        children: [
          _PlanHeader(
            fixed: fixed,
            total: items.length,
            source: test?.title ?? 'a practice test',
            createdAt: plan.createdAt,
          ),
          const SizedBox(height: 16),
          if (allFixed) ...[
            Card(
              key: const ValueKey('plan-complete'),
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Every gap is fixed',
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Take another mock exam to check for new gaps.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go('/practice'),
                      child: const Text('Take a mock exam'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final (i, item) in items.indexed) ...[
            _GapItemCard(index: i, status: item, progress: progress),
            const SizedBox(height: 12),
          ],
          if (!allFixed)
            FilledButton.icon(
              key: const ValueKey('plan-retest'),
              onPressed: () => context.go('/progress/review?kind=plan'),
              icon: const Icon(Icons.replay),
              label: const Text('Re-test my gaps'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    ContentBundle content,
    ProgressStore progress,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this plan?'),
        content: const Text(
          'Your answers and progress stay. Only the plan is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const ValueKey('confirm-discard'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true) progress.clearGapPlan(content.subject.id);
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.fixed,
    required this.total,
    required this.source,
    required this.createdAt,
  });

  final int fixed;
  final int total;
  final String source;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = createdAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$fixed of $total gaps fixed',
          key: const ValueKey('plan-summary'),
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text('From $source · $date', style: textTheme.bodySmall),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: total == 0 ? 0 : fixed / total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          semanticsLabel: 'Gap plan progress',
        ),
        const SizedBox(height: 10),
        Text(
          'For each gap: re-read the notes, review the flashcards, then '
          'pass a targeted quiz. A gap is fixed at 80% on your latest '
          'answers, with at least half its questions answered.',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _GapItemCard extends StatelessWidget {
  const _GapItemCard({
    required this.index,
    required this.status,
    required this.progress,
  });

  final int index;
  final GapItemStatus status;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final acc = s.stats.accuracy;
    final notesTopic = s.notesTopic(progress);
    final cardsTopic = s.cardsTopic(progress);

    return Card(
      key: ValueKey('plan-item-${s.competency.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.competency.text, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(s.domain.title, style: textTheme.labelMedium),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: s.fixed
                      ? Chip(
                          avatar: Icon(Icons.check, color: scheme.primary),
                          label: const Text('Fixed'),
                        )
                      : Text('${s.stepsDone}/3', style: textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Exam: ${s.item.examCorrect}/${s.item.examTotal} correct · '
              '${acc == null ? 'not practised yet' : 'now ${(acc * 100).round()}% '
                        '(${s.stats.seen} of ${s.stats.total} answered)'}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            _Step(
              key: ValueKey('plan-step-notes-${s.competency.id}'),
              done: s.notesDone,
              title: 'Re-read the notes',
              subtitle: s.topics.map((t) => t.title).join(' · '),
              onTap: notesTopic == null
                  ? null
                  : () => context.go('/topic/${notesTopic.id}/notes'),
            ),
            _Step(
              key: ValueKey('plan-step-cards-${s.competency.id}'),
              done: s.cardsDone,
              title: 'Review the flashcards',
              subtitle: cardsTopic == null ? '' : cardsTopic.title,
              onTap: cardsTopic == null
                  ? null
                  : () => context.go('/topic/${cardsTopic.id}/cards'),
            ),
            _Step(
              key: ValueKey('plan-step-quiz-${s.competency.id}'),
              done: s.fixed,
              title: 'Pass a targeted quiz',
              subtitle: '80% or more on this competency',
              onTap: () => context.go(
                '/progress/review?kind=competency&id=${s.competency.id}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    super.key,
    required this.done,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? scheme.primary : scheme.outline,
        semanticLabel: done ? 'Done' : 'To do',
      ),
      title: Text(title),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Compact plan summary for Home and Progress. Without a plan it renders
/// nothing, or (with [promptExam]) an invitation to take a mock exam.
class GapPlanSummaryCard extends StatelessWidget {
  const GapPlanSummaryCard({super.key, this.promptExam = false});

  final bool promptExam;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentBundle>();
    final progress = context.watch<ProgressStore>();
    final plan = progress.gapPlan(content.subject.id);
    if (plan == null) {
      if (!promptExam || content.practiceTests.isEmpty) {
        return const SizedBox.shrink();
      }
      return Card(
        key: const ValueKey('plan-prompt'),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Find your gaps'),
          subtitle: const Text(
            'Take a mock exam and get a plan for what to study next.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/practice'),
        ),
      );
    }
    final items = planStatus(content, progress, plan);
    if (items.isEmpty) return const SizedBox.shrink();
    final fixed = items.where((i) => i.fixed).length;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final next = items.where((i) => !i.fixed).firstOrNull;
    return Card(
      key: const ValueKey('plan-card'),
      child: InkWell(
        onTap: () => context.go('/progress/plan'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: fixed / items.length,
                      strokeWidth: 5,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                    Icon(Icons.flag, size: 18, color: scheme.primary),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gap plan · $fixed of ${items.length} fixed',
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next == null
                          ? 'All fixed. Take another exam to check.'
                          : 'Next: ${next.competency.text}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
