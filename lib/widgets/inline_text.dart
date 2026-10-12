import 'package:material_ui/material_ui.dart';

import '../content/inline_markup.dart' as markup;

/// Renders text with the allowed inline markup: `code` and **bold**.
///
/// With [leadIn], a short "Label:" prefix (see [markup.leadInLength]) is
/// rendered bold too.
class InlineText extends StatelessWidget {
  const InlineText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.leadIn = false,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool leadIn;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final scheme = Theme.of(context).colorScheme;
    final lead = leadIn ? markup.leadInLength(text) : 0;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          if (lead > 0)
            TextSpan(
              style: const TextStyle(fontWeight: FontWeight.w700),
              children: _spans(text.substring(0, lead), base, scheme),
            ),
          ..._spans(text.substring(lead), base, scheme),
        ],
      ),
      textAlign: textAlign,
    );
  }

  static List<TextSpan> _spans(
    String text,
    TextStyle base,
    ColorScheme scheme,
  ) => [
    for (final span in markup.parseInline(text))
      switch (span.style) {
        markup.InlineStyle.plain => TextSpan(text: span.text),
        markup.InlineStyle.bold => TextSpan(
          text: span.text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        markup.InlineStyle.code => TextSpan(
          text: span.text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Courier New', 'Courier'],
            fontSize: (base.fontSize ?? 16) * 0.92,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      },
  ];
}
