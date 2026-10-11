import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/models.dart';

Future<void> openExternal(String url) =>
    launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');

/// "Source: <title>" link (with an open-in-new icon) that opens the documentation page in a new tab.
class SourceLink extends StatelessWidget {
  const SourceLink({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.parse(url);
    final label =
        title ??
        context.read<ContentBundle>().sourceTitle(url) ??
        uri.host + uri.path;
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => openExternal(url),
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Source: $label '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(Icons.open_in_new, size: 14, color: color),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
