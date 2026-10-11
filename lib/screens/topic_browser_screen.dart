import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../content/models.dart';
import '../engine/clock.dart';
import '../progress/insights.dart';
import '../progress/progress_store.dart';
import '../widgets/page_body.dart';
import '../widgets/progress_ring.dart';
import '../widgets/subject_switcher.dart';
import '../widgets/topic_status.dart';

/// S1 — where you are (continue card, reviews due) and every topic grouped
/// by domain, in study order.
class TopicBrowserScreen extends StatelessWidget {
  const TopicBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentBundle>();
    final progress = context.watch<ProgressStore>();
    final ads = context.read<AdsService>();
    final now = context.read<Clock>().now();

    final due = dueCardCount(content, progress, now);
    final missed = missedQuestions(content, progress).length;

    return Scaffold(
      appBar: AppBar(
        title: const SubjectTitle(),
        actions: [
          IconButton(
            key: const ValueKey('open-search'),
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      body: PageList(
        children: [
          _ContinueCard(content: content, progress: progress),
          if (due > 0 || missed > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (due > 0)
                  ActionChip(
                    key: const ValueKey('chip-due-cards'),
                    avatar: const Icon(Icons.style_outlined, size: 18),
                    label: Text('$due ${due == 1 ? 'card' : 'cards'} due'),
                    onPressed: () => context.go('/progress/cards'),
                  ),
                if (missed > 0)
                  ActionChip(
                    key: const ValueKey('chip-missed'),
                    avatar: const Icon(Icons.replay, size: 18),
                    label: Text(
                      '$missed missed ${missed == 1 ? 'question' : 'questions'}',
                    ),
                    onPressed: () => context.go('/progress/review?kind=missed'),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.insights_outlined, size: 18),
                  label: const Text('Find my gaps'),
                  onPressed: () => context.go('/progress'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          for (final domain in content.domainsInDisplayOrder)
            _DomainSection(
              content: content,
              domain: domain,
              topics: content.topicsForDomain(domain.id),
            ),
          ads.banner(AdPlacement.topicListBanner),
        ],
      ),
    );
  }
}

/// "Where am I": the next recommended step and overall position.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.content, required this.progress});

  final ContentBundle content;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final total = content.topics.length;
    final complete = content.topics.where(progress.topicComplete).length;
    final next = nextAction(content, progress);

    return Card(
      key: const ValueKey('continue-card'),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$complete of $total topics complete',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: total == 0 ? 0 : complete / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              semanticsLabel: 'Overall progress',
            ),
            const SizedBox(height: 14),
            if (total == 0)
              Text(
                'No topics yet for this subject.',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              )
            else if (next == null) ...[
              Text(
                'Every topic is complete',
                style: textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep your flashcards up to date and try a practice test.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/practice'),
                child: const Text('Practice tests'),
              ),
            ] else ...[
              Text(
                '${next.resuming ? 'Continue' : (complete == 0 && !progress.topicStarted(next.topic) ? 'Start here' : 'Up next')}'
                ' · Topic ${next.position} of ${next.total}',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                next.topic.title,
                style: textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              TopicStepRow(topic: next.topic),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('continue-button'),
                onPressed: () => context.go(stepPath(next.topic, next.step)),
                icon: const Icon(Icons.play_arrow),
                label: Text(stepLabel(next.step)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A domain heading with progress; tap to collapse. Fully completed domains
/// start collapsed so the list stays focused on what's left.
class _DomainSection extends StatefulWidget {
  const _DomainSection({
    required this.content,
    required this.domain,
    required this.topics,
  });

  final ContentBundle content;
  final Domain domain;
  final List<Topic> topics;

  @override
  State<_DomainSection> createState() => _DomainSectionState();
}

class _DomainSectionState extends State<_DomainSection> {
  late bool _expanded =
      !(widget.topics.isNotEmpty &&
          widget.topics.every(context.read<ProgressStore>().topicComplete));

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final domain = widget.domain;
    final topics = widget.topics;
    final progress = context.watch<ProgressStore>();
    final textTheme = Theme.of(context).textTheme;
    final complete = topics.where(progress.topicComplete).length;
    final weight = domain.weightPercent == null
        ? (domain.isExamDomain ? '' : 'Prerequisites')
        : '${domain.weightPercent}% of ${content.exam?.name ?? 'exam'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('domain-${domain.id}'),
            borderRadius: BorderRadius.circular(8),
            onTap: topics.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            domain.title,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (weight.isNotEmpty) weight,
                            if (topics.isNotEmpty)
                              '$complete/${topics.length} complete',
                          ].join(' · '),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (topics.isNotEmpty)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      semanticLabel: _expanded ? 'Collapse' : 'Expand',
                    ),
                ],
              ),
            ),
          ),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: topics.isEmpty ? 0 : complete / topics.length,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
          const SizedBox(height: 10),
          if (!_expanded)
            const SizedBox.shrink()
          else if (topics.isEmpty)
            const Card(
              child: ListTile(
                enabled: false,
                leading: Icon(Icons.schedule),
                title: Text('Coming later'),
                subtitle: Text('No topics for this domain yet.'),
              ),
            )
          else
            for (final t in topics)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TopicCard(
                  topic: t,
                  position: content.topics.indexOf(t) + 1,
                ),
              ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.position});

  final Topic topic;
  final int position;

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressStore>();
    final textTheme = Theme.of(context).textTheme;
    final complete = progress.topicComplete(topic);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('topic-card-${topic.id}'),
        onTap: () => context.go('/topic/${topic.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ProgressRing(value: progress.topicProgress(topic), size: 40),
                  complete
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : Text('$position', style: textTheme.labelMedium),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.title, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      topic.summary,
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    TopicStepRow(topic: topic),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text('${topic.estMinutes}m', style: textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
