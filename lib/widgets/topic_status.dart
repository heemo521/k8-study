import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../content/models.dart';
import '../engine/quiz.dart';
import '../progress/progress_store.dart';

/// Compact "Notes · Cards · Quiz" status row for a topic card.
class TopicStepRow extends StatelessWidget {
  const TopicStepRow({super.key, required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProgressStore>();
    final read = p.readCount(topic);
    final total = topic.sections.length;
    final started = topic.flashcards
        .where((c) => p.cardState(c.id) != null)
        .length;
    final best = p.quizStats(topic.id)?.bestPct;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        StepChip(
          label: read == total ? 'Notes' : 'Notes $read/$total',
          state: read == total
              ? ProgressState.done
              : (read > 0 ? ProgressState.partial : ProgressState.todo),
        ),
        StepChip(
          label: started == 0
              ? 'Cards'
              : 'Cards $started/${topic.flashcards.length}',
          state: started == topic.flashcards.length
              ? ProgressState.done
              : (started > 0 ? ProgressState.partial : ProgressState.todo),
        ),
        StepChip(
          label: best == null ? 'Quiz' : 'Quiz $best%',
          state: best == null
              ? ProgressState.todo
              : (best >= masteryPercent
                    ? ProgressState.done
                    : ProgressState.weak),
        ),
      ],
    );
  }
}

enum ProgressState { todo, partial, weak, done }

class StepChip extends StatelessWidget {
  const StepChip({super.key, required this.label, required this.state});

  final String label;
  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, fg, bg) = switch (state) {
      ProgressState.done => (
        Icons.check_circle,
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
      ProgressState.partial => (
        Icons.timelapse,
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
      ProgressState.weak => (
        Icons.error_outline,
        scheme.onErrorContainer,
        scheme.errorContainer,
      ),
      ProgressState.todo => (
        Icons.radio_button_unchecked,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
    };
    final name = switch (state) {
      ProgressState.done => 'done',
      ProgressState.partial => 'in progress',
      ProgressState.weak => 'below mastery',
      ProgressState.todo => 'not started',
    };
    return Semantics(
      label: '$label, $name',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            // Flexible so large text sizes ellipsize instead of overflowing.
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
