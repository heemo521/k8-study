import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../content/models.dart';
import '../widgets/page_body.dart';
import '../widgets/source_link.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// S11 — what the app is, attribution, trademark and disclaimers. No ads.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentBundle>();
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
    Widget link(String label, String url) => InkWell(
          onTap: () => openExternal(url),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$label '),
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

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: PageList(children: [
        Text('K8 Study', style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        para('Short notes, flashcards, quizzes and practice tests for learning '
            'Kubernetes and preparing for the CKA exam. Your progress stays on '
            'this device. There is no account and no server.'),
        para('Not affiliated with the CNCF, The Linux Foundation, or the '
            'Kubernetes project.'),

        heading('Attribution'),
        Container(
          key: const ValueKey('attribution'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            para('Study notes are original summaries adapted from the '
                'Kubernetes Documentation, © The Kubernetes Authors, licensed '
                'under CC BY 4.0. Changes: content has been summarized, '
                'reorganized, and rewritten. Each note links to its source page.'),
            link('Kubernetes Documentation', 'https://kubernetes.io/docs/'),
            link('CC BY 4.0 license', 'https://creativecommons.org/licenses/by/4.0/'),
            const SizedBox(height: 8),
            para('Some notes on minikube are adapted from the minikube '
                'documentation, © The Kubernetes Authors.'),
            link('minikube documentation', 'https://minikube.sigs.k8s.io/docs/'),
            const SizedBox(height: 8),
            para('The Managed Kubernetes topic states basic facts about Amazon '
                'EKS, Google GKE and Azure AKS and links to each vendor’s own '
                'documentation. Product names belong to their owners.'),
          ]),
        ),

        heading('Trademarks'),
        para('Kubernetes® is a registered trademark of The Linux Foundation.'),
        link('Linux Foundation trademark usage',
            'https://www.linuxfoundation.org/legal/trademark-usage'),
        link('LF Projects policies', 'https://lfprojects.org/policies/'),

        heading('CKA curriculum'),
        para('The topic-to-domain mapping follows the public CKA curriculum '
            'page (domains and weights checked ${content.curriculum.checkedAt}; '
            'exam based on Kubernetes v${content.curriculum.examK8sVersion}). '
            'This app is not endorsed by The Linux Foundation. The real exam '
            'is hands-on; the quizzes here are knowledge checks.'),
        SourceLink(url: content.curriculum.source, title: 'CKA curriculum'),

        if (ads.enabled) ...[
          heading('Ads'),
          para('This build shows ad placeholders on some screens. Ads never '
              'appear during quizzes, flashcards or practice tests.'),
        ],

        heading('Version'),
        para('App $appVersion · content v${content.manifest.contentVersion}, '
            'reviewed ${content.manifest.reviewedAt}'),
      ]),
    );
  }
}
