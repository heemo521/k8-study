import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../content/models.dart';
import '../progress/progress_store.dart';
import '../widgets/page_body.dart';
import '../widgets/progress_ring.dart';

/// S1 — topics grouped by CKA domain.
class TopicBrowserScreen extends StatelessWidget {
  const TopicBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentBundle>();
    final progress = context.watch<ProgressStore>();
    final ads = context.read<AdsService>();
    final textTheme = Theme.of(context).textTheme;
    final complete = content.topics.where(progress.topicComplete).length;
    final total = content.topics.length;

    return Scaffold(
      appBar: AppBar(title: const Text('K8 Study')),
      body: PageList(children: [
        Text('$complete of $total topics complete', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: total == 0 ? 0 : complete / total,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          semanticsLabel: 'Overall progress',
        ),
        const SizedBox(height: 16),
        for (final domain in content.domainsInDisplayOrder)
          _DomainSection(domain: domain, topics: content.topicsForDomain(domain.id)),
        ads.banner(AdPlacement.topicListBanner),
      ]),
    );
  }
}

class _DomainSection extends StatelessWidget {
  const _DomainSection({required this.domain, required this.topics});

  final Domain domain;
  final List<Topic> topics;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = domain.weightPercent == null
        ? domain.title
        : '${domain.title} · ${domain.weightPercent}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              header: true,
              child: Text(title, style: textTheme.titleMedium),
            ),
          ),
          if (!domain.isExamDomain)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Prerequisites — not an exam domain.',
                  style: textTheme.bodySmall),
            ),
          if (topics.isEmpty)
            Card(
              child: ListTile(
                enabled: false,
                leading: const Icon(Icons.schedule),
                title: const Text('Coming later'),
                subtitle: const Text('No topics for this domain yet.'),
              ),
            )
          else
            for (final t in topics)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TopicCard(topic: t),
              ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressStore>();
    final textTheme = Theme.of(context).textTheme;
    final status = progress.topicComplete(topic)
        ? 'Complete'
        : progress.topicStarted(topic)
            ? 'In progress'
            : 'Not started';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('topic-card-${topic.id}'),
        onTap: () => context.go('/topic/${topic.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProgressRing(value: progress.topicProgress(topic)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.title, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(topic.summary, style: textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      _Chip(status),
                      _Chip('${topic.estMinutes} min'),
                    ]),
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

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSecondaryContainer)),
    );
  }
}
