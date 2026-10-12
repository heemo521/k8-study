import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../progress/progress_store.dart';
import '../progress/rewards.dart';

/// "+N XP" line for a results screen; empty when nothing was earned.
class XpEarned extends StatelessWidget {
  const XpEarned(this.xp, {super.key});

  final int xp;

  @override
  Widget build(BuildContext context) {
    if (xp <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final level = context.watch<ProgressStore>().level;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '+$xp XP · Level ${level.level}',
        key: const ValueKey('xp-earned'),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: scheme.primary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Level, XP to the next level, and the daily streak (Progress screen).
class RewardsCard extends StatelessWidget {
  const RewardsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressStore>();
    final textTheme = Theme.of(context).textTheme;
    final level = progress.level;
    final streak = progress.streak;
    final best = progress.bestStreak;
    return Card(
      key: const ValueKey('rewards-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Level ${level.level}',
                    style: textTheme.titleMedium,
                  ),
                ),
                Text('${progress.xp} XP', style: textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: level.fraction,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              semanticsLabel: 'Progress to level ${level.level + 1}',
            ),
            const SizedBox(height: 4),
            Text(
              '${level.needed - level.into} XP to level ${level.level + 1}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_fire_department),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${streak == 0 ? 'Study today to start a streak' : '$streak-day streak'}'
                    '${best > streak ? ' · best $best' : ''}',
                    key: const ValueKey('streak-summary'),
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'XP: ${Xp.sectionRead} per note section, ${Xp.cardReviewed} per '
              'flashcard, ${Xp.correctAnswer} per correct answer '
              '(${Xp.wrongAnswer} if wrong), ${Xp.quizMastered} for mastering '
              'a topic quiz.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
