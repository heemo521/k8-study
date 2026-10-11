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
class TopicDetailScreen extends StatelessWidget {
  const TopicDetailScreen({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentBundle>();
    final topic = content.topic(topicId);
    if (topic == null) return const NotFoundView(message: 'Topic not found.');

    final progress = context.watch<ProgressStore>();
    final now = context.read<Clock>().now();
    final textTheme = Theme.of(context).textTheme;

    final read = progress.readCount(topic);
    final notesDone = progress.notesComplete(topic);
    final due = fc.dueCount(topic.flashcards, progress.cardStates, now);
    final cardsStarted =
        topic.flashcards.any((c) => progress.cardState(c.id) != null);
    final stats = progress.quizStats(topic.id);

    final base = '/topic/${topic.id}';
    final (nextLabel, nextPath) = !notesDone
        ? ('Continue notes', '$base/notes')
        : !cardsStarted
            ? ('Start flashcards', '$base/cards')
            : ('Take the quiz', '$base/quiz');

    return Scaffold(
      appBar: AppBar(title: Text(topic.title)),
      body: PageList(children: [
        Text(topic.summary, style: textTheme.bodyLarge),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in topic.domainIds)
            Chip(label: Text(content.domain(d)?.title ?? d)),
          Chip(label: Text('${topic.estMinutes} min')),
        ]),
        if (topic.competencyIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('CKA competencies', style: textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final c in topic.competencyIds)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• ${content.competencyText(c) ?? c}',
                  style: textTheme.bodyMedium),
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
          status: '$due due · ${topic.flashcards.length} total · '
              '${progress.masteredCount(topic.flashcards)} mastered',
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
        Text('Content reviewed ${topic.reviewedAt}.', style: textTheme.bodySmall),
      ]),
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
            ? Icon(Icons.check_circle, color: scheme.primary, semanticLabel: 'Done')
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
