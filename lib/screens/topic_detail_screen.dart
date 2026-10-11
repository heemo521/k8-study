import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../content/models.dart';
import '../engine/clock.dart';
import '../engine/flashcards.dart' as fc;
import '../progress/progress_store.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/source_link.dart';

/// S2 — hub for one topic: Notes → Flashcards → Quiz.
class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({super.key, required this.topicId});

  final String topicId;

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  @override
  void initState() {
    super.initState();
    final content = context.read<ContentBundle>();
    if (content.topic(widget.topicId) != null) {
      // Deferred: notifying listeners during the first build isn't allowed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ProgressStore>().markTopicVisited(
            content.subject.id,
            widget.topicId,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicId = widget.topicId;
    final content = context.watch<ContentBundle>();
    final topic = content.topic(topicId);
    if (topic == null) return const NotFoundView(message: 'Topic not found.');
    final index = content.topics.indexOf(topic);
    final prev = index > 0 ? content.topics[index - 1] : null;
    final next = index + 1 < content.topics.length
        ? content.topics[index + 1]
        : null;

    final progress = context.watch<ProgressStore>();
    final now = context.read<Clock>().now();
    final textTheme = Theme.of(context).textTheme;

    final read = progress.readCount(topic);
    final notesDone = progress.notesComplete(topic);
    final due = fc.dueCount(topic.flashcards, progress.cardStates, now);
    final fresh = topic.flashcards
        .where((c) => progress.cardState(c.id) == null)
        .length;
    final cardsStarted = topic.flashcards.any(
      (c) => progress.cardState(c.id) != null,
    );
    final stats = progress.quizStats(topic.id);

    final base = '/topic/${topic.id}';
    final (nextLabel, nextPath) = !notesDone
        ? (read == 0 ? 'Start the notes' : 'Continue notes', '$base/notes')
        : !cardsStarted
        ? ('Start flashcards', '$base/cards')
        : ('Take the quiz', '$base/quiz');

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: PageList(
        children: [
          Text(
            'Topic ${index + 1} of ${content.topics.length}',
            key: const ValueKey('topic-position'),
            style: textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(topic.summary, style: textTheme.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in topic.domainIds)
                Chip(label: Text(content.domain(d)?.title ?? d)),
              Chip(label: Text('${topic.estMinutes} min')),
            ],
          ),
          if (topic.prerequisites.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Study first', style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in topic.prerequisites)
                  if (content.topic(id) case final pre?)
                    ActionChip(
                      avatar: Icon(
                        progress.topicComplete(pre)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      label: Text(pre.title),
                      onPressed: () => context.go('/topic/${pre.id}'),
                    ),
              ],
            ),
          ],
          if (topic.competencyIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              content.exam == null
                  ? 'Skills covered'
                  : '${content.exam!.name} competencies',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final c in topic.competencyIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${content.competencyText(c) ?? c}',
                  style: textTheme.bodyMedium,
                ),
              ),
          ],
          const SizedBox(height: 16),
          _StepTile(
            key: const ValueKey('step-notes'),
            icon: Icons.article_outlined,
            title: '1. Study notes',
            status: '$read of ${topic.sections.length} sections read',
            done: notesDone,
            onTap: () => context.go('$base/notes'),
          ),
          _StepTile(
            key: const ValueKey('step-cards'),
            icon: Icons.style_outlined,
            title: '2. Flashcards',
            status: [
              if (fresh > 0) '$fresh new',
              if (due - fresh > 0) '${due - fresh} due',
              if (due == 0) 'nothing due',
              '${progress.masteredCount(topic.flashcards)}/${topic.flashcards.length} mastered',
            ].join(' · '),
            done: cardsStarted && due == 0,
            onTap: () => context.go('$base/cards'),
          ),
          _StepTile(
            key: const ValueKey('step-quiz'),
            icon: Icons.quiz_outlined,
            title: '3. Quiz',
            status: stats == null
                ? 'Not taken'
                : 'Best ${stats.bestPct}% · ${stats.attempts} '
                      '${stats.attempts == 1 ? 'attempt' : 'attempts'}',
            done: progress.quizPassed(topic.id),
            onTap: () => context.go('$base/quiz'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('next-step'),
            onPressed: () => context.go(nextPath),
            child: Text(nextLabel),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Sources (${topic.sourceUrls.length})'),
            children: [
              for (final url in topic.sourceUrls) SourceLink(url: url),
            ],
          ),
          Text(
            'Content reviewed ${topic.reviewedAt}.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (prev != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go('/topic/${prev.id}'),
                      icon: const Icon(Icons.chevron_left),
                      label: Text(prev.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (next != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('next-topic-link'),
                      onPressed: () => context.go('/topic/${next.id}'),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.chevron_right),
                      label: Text(next.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(status),
        trailing: done
            ? Icon(
                Icons.check_circle,
                color: scheme.primary,
                semanticLabel: 'Done',
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
