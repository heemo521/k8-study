import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../content/models.dart';
import '../widgets/page_body.dart';
import '../widgets/source_link.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.1.0');

/// S11 — what the app is, attribution, trademarks and disclaimers for every
/// subject (all from subject.json). No ads.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final ads = context.read<AdsService>();
    final textTheme = Theme.of(context).textTheme;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 6),
          child: Semantics(header: true, child: Text(text, style: textTheme.titleMedium)),
        );
    Widget para(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: textTheme.bodyMedium),
        );
    Widget link(LinkRef l) => InkWell(
          onTap: () => openExternal(l.url),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${l.label} '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(Icons.open_in_new,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                  ),
                ]),
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
    List<Widget> notice(Notice n) => [para(n.text), for (final l in n.links) link(l)];

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: PageList(children: [
        Text('K8 Study', style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        para('Short notes, flashcards, quizzes and practice tests. Your progress '
            'stays on this device. There is no account and no server.'),
        para('Not affiliated with the CNCF, The Linux Foundation, the Kubernetes '
            'project, or any other project whose documentation is cited.'),
        for (final s in catalog.subjects) ...[
          heading(catalog.subjects.length > 1
              ? '${s.subject.title}: attribution'
              : 'Attribution'),
          Container(
            key: ValueKey('attribution-${s.subject.id}'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in s.subject.attributions) ...[
                  ...notice(n),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (s.subject.trademarks.isNotEmpty) ...[
            heading('Trademarks'),
            for (final n in s.subject.trademarks) ...notice(n),
          ],
          if (s.exam case final exam?) ...[
            heading('${exam.name} curriculum'),
            para('The topic-to-domain mapping follows the public ${exam.title} '
                'curriculum (checked ${exam.checkedAt}; exam based on '
                '${exam.examVersion}). This app is not endorsed by the exam '
                'provider. ${exam.note}'),
            SourceLink(url: exam.source, title: '${exam.name} curriculum'),
          ],
          para('Content v${s.subject.contentVersion}, reviewed ${s.subject.reviewedAt}.'),
        ],
        if (ads.enabled) ...[
          heading('Ads'),
          para('This build shows ad placeholders on some screens. Ads never '
              'appear during quizzes, flashcards or practice tests.'),
        ],
        heading('Version'),
        para('App $appVersion'),
      ]),
    );
  }
}
