import 'package:material_ui/material_ui.dart';

import '../content/inline_markup.dart' as markup;

/// Renders text with the allowed inline markup: `code` and **bold**.
class InlineText extends StatelessWidget {
  const InlineText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final span in markup.parseInline(text))
            switch (span.style) {
              markup.InlineStyle.plain => TextSpan(text: span.text),
              markup.InlineStyle.bold => TextSpan(
                  text: span.text,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
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
        ],
      ),
      textAlign: textAlign,
    );
  }
}
