import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../content/models.dart';
import '../engine/practice.dart';
import '../progress/progress_store.dart';
import '../widgets/page_body.dart';

/// S7 — pick a practice test.
class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentBundle>();
    final progress = context.watch<ProgressStore>();
    final ads = context.read<AdsService>();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final coveredDomains = {
      for (final t in content.topics)
        if (t.questions.isNotEmpty) ...t.domainIds,
    };
    final uncovered = content.curriculum.domains
        .where((d) => d.isExamDomain && !coveredDomains.contains(d.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: PageList(children: [
        Card(
          color: scheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'The real CKA is a hands-on, performance-based exam. These '
              'multiple-choice tests check your knowledge of the concepts; '
              'they are not a simulation of the exam.',
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final test in content.practiceTests)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                key: ValueKey('practice-${test.id}'),
                title: Text(test.title),
                subtitle: Text(
                  '${_count(test, content)} questions · '
                  '${test.timeLimitMinutes} min'
                  '${progress.bestPracticePct(test.id) == null ? '' : ' · best ${progress.bestPracticePct(test.id)}%'}'
                  '\n${test.description}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _showSetup(context, test),
              ),
            ),
          ),
        if (uncovered.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Coming later', style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'No questions yet for: ${uncovered.map((d) => d.title).join(', ')}.',
            style: textTheme.bodySmall,
          ),
        ],
        ads.banner(AdPlacement.practiceHubBanner),
      ]),
    );
  }

  static int _count(PracticeTestDef test, ContentBundle content) {
    final pool = practicePool(test, content).length;
    return pool < test.questionCount ? pool : test.questionCount;
  }

  Future<void> _showSetup(BuildContext context, PracticeTestDef test) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final progress = sheetContext.watch<ProgressStore>();
        return SafeArea(
          child: PageWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(test.title,
                      style: Theme.of(sheetContext).textTheme.titleMedium),
                  SwitchListTile(
                    key: const ValueKey('timer-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text('Timer (${test.timeLimitMinutes} min)'),
                    value: progress.practiceTimerOn,
                    onChanged: (v) => progress.practiceTimerOn = v,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const ValueKey('start-test'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.go('/practice/${test.id}/run');
                    },
                    child: const Text('Start'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
