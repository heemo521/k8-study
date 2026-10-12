import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'gap_plan_screen.dart';
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
          if (!progress.introDismissed) ...[
            _IntroCard(onDismiss: progress.dismissIntro),
            const SizedBox(height: 12),
          ],
          _ContinueCard(content: content, progress: progress),
          if (progress.gapPlan(content.subject.id) != null) ...[
            const SizedBox(height: 12),
            const GapPlanSummaryCard(),
          ],
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
              key: ValueKey('${content.subject.id}/${domain.id}'),
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
    final fg = scheme.onPrimary;
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: scheme.onPrimary,
      foregroundColor: scheme.primary,
    );

    return DecoratedBox(
      key: const ValueKey('continue-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.4)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$complete of $total topics complete',
                    style: textTheme.labelLarge?.copyWith(color: fg),
                  ),
                ),
                Semantics(
                  label: 'Level ${progress.level.level}, ${progress.xp} XP',
                  excludeSemantics: true,
                  child: Row(
                    key: const ValueKey('level'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 18, color: fg),
                      Text(
                        'Lv ${progress.level.level}',
                        style: textTheme.labelLarge?.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
                if (progress.streak > 0) ...[
                  const SizedBox(width: 10),
                  Semantics(
                    label: '${progress.streak} day study streak',
                    excludeSemantics: true,
                    child: Row(
                      key: const ValueKey('streak'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, size: 18, color: fg),
                        Text(
                          '${progress.streak}',
                          style: textTheme.labelLarge?.copyWith(color: fg),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (_todaySummary(progress.today) case final today?)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  today,
                  key: const ValueKey('today-summary'),
                  style: textTheme.bodySmall?.copyWith(color: fg),
                ),
              ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: total == 0 ? 0 : complete / total,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: fg,
              backgroundColor: fg.withValues(alpha: 0.25),
              semanticsLabel: 'Overall progress',
            ),
            const SizedBox(height: 14),
            if (total == 0)
              Text(
                'No topics yet for this subject.',
                style: textTheme.titleMedium?.copyWith(color: fg),
              )
            else if (next == null) ...[
              Text(
                'Every topic is complete',
                style: textTheme.titleLarge?.copyWith(color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep your flashcards up to date and try a practice test.',
                style: textTheme.bodyMedium?.copyWith(color: fg),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: buttonStyle,
                onPressed: () => context.go('/practice'),
                child: const Text('Practice tests'),
              ),
            ] else ...[
              Text(
                '${next.resuming ? 'Continue' : (complete == 0 && !progress.topicStarted(next.topic) ? 'Start here' : 'Up next')}'
                ' · Topic ${next.position} of ${next.total}',
                style: textTheme.labelMedium?.copyWith(color: fg),
              ),
              const SizedBox(height: 2),
              Text(
                next.topic.title,
                style: textTheme.headlineSmall?.copyWith(color: fg),
              ),
              const SizedBox(height: 8),
              TopicStepRow(topic: next.topic),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('continue-button'),
                style: buttonStyle,
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
    super.key,
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
        ? (domain.isExamDomain || content.exam == null ? '' : 'Prerequisites')
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

/// First-run explainer of the study loop; dismissed once, remembered.
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget step(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: textTheme.bodyMedium)),
        ],
      ),
    );
    return Card(
      key: const ValueKey('intro-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            step(
              Icons.article_outlined,
              'Read a topic\'s short notes. Each links to its source page.',
            ),
            step(
              Icons.style_outlined,
              'Review its flashcards. They come back on a spaced schedule.',
            ),
            step(
              Icons.quiz_outlined,
              'Pass its quiz with 80% or more to complete the topic.',
            ),
            step(
              Icons.insights_outlined,
              'Progress shows your weakest areas, with a review for each.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('dismiss-intro'),
                onPressed: onDismiss,
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Today: 3 sections, 12 cards, 1 quiz", or null when nothing yet.
String? _todaySummary(Map<String, int> today) {
  String part(String key, String one, String many) {
    final n = today[key] ?? 0;
    return n == 0 ? '' : '$n ${n == 1 ? one : many}';
  }

  final parts = [
    part('sections', 'section', 'sections'),
    part('cards', 'card', 'cards'),
    part('quizzes', 'quiz', 'quizzes'),
  ].where((p) => p.isNotEmpty);
  return parts.isEmpty ? null : 'Today: ${parts.join(', ')}';
}
