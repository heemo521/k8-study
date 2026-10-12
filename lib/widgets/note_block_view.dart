import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../content/models.dart';
import 'diagram_view.dart';
import 'inline_text.dart';

/// Renders one structured note block (spec §5.3).
class NoteBlockView extends StatelessWidget {
  const NoteBlockView(this.block, {super.key});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (block) {
        ParagraphBlock(:final text) => InlineText(text, style: body),
        BulletsBlock(:final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: body),
                    Expanded(child: InlineText(item, style: body)),
                  ],
                ),
              ),
          ],
        ),
        CodeBlock(:final text) => _CodeView(text: text),
        CalloutBlock(:final kind, :final text) => _Callout(
          kind: kind,
          text: text,
        ),
        TableBlock(:final header, :final rows) => _TableView(
          header: header,
          rows: rows,
        ),
        DiagramBlock() => DiagramView(block: block as DiagramBlock),
      },
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: SelectableText(
                text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Courier New', 'Courier'],
                  fontSize: 14,
                  height: 1.4,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copied')));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.kind, required this.text});

  final CalloutKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, bg, fg) = switch (kind) {
      CalloutKind.key => (
        Icons.lightbulb_outline,
        'Key point',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      CalloutKind.exam => (
        Icons.school_outlined,
        'Exam tip',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      CalloutKind.warn => (
        Icons.warning_amber_outlined,
        'Watch out',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      CalloutKind.story => (
        Icons.directions_boat_outlined,
        'Port story',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20, semanticLabel: label),
          const SizedBox(width: 10),
          Expanded(
            child: InlineText(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.header, required this.rows});

  final List<String> header;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cellStyle = textTheme.bodyMedium?.copyWith(fontSize: 14);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the viewport when possible; scroll horizontally inside the box
        // otherwise (never the page).
        final minWidth = header.length * 110.0;
        final width = constraints.maxWidth > minWidth
            ? constraints.maxWidth
            : minWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Table(
              border: TableBorder.all(color: scheme.outlineVariant),
              columnWidths: {
                for (var i = 0; i < header.length; i++)
                  i: const FlexColumnWidth(),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                  ),
                  children: [
                    for (final h in header)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          h,
                          style: cellStyle?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final row in rows)
                  TableRow(
                    children: [
                      for (final cell in row)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: InlineText(cell, style: cellStyle),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
