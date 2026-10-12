/// Parser for the tiny inline markup allowed in note text (spec §5.3):
/// `` `code` `` and `**bold**`. Anything else is literal text, and an
/// unterminated marker is rendered literally too.
library;

enum InlineStyle { plain, bold, code }

class InlineSpan {
  const InlineSpan(this.text, this.style);

  final String text;
  final InlineStyle style;

  @override
  bool operator ==(Object other) =>
      other is InlineSpan && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => '${style.name}("$text")';
}

List<InlineSpan> parseInline(String input) {
  final spans = <InlineSpan>[];
  final plain = StringBuffer();

  void flushPlain() {
    if (plain.isNotEmpty) {
      spans.add(InlineSpan(plain.toString(), InlineStyle.plain));
      plain.clear();
    }
  }

  var i = 0;
  while (i < input.length) {
    if (input[i] == '`') {
      final end = input.indexOf('`', i + 1);
      if (end > i + 1) {
        flushPlain();
        spans.add(InlineSpan(input.substring(i + 1, end), InlineStyle.code));
        i = end + 1;
        continue;
      }
    } else if (input.startsWith('**', i)) {
      final end = input.indexOf('**', i + 2);
      if (end > i + 2) {
        flushPlain();
        spans.add(InlineSpan(input.substring(i + 2, end), InlineStyle.bold));
        i = end + 2;
        continue;
      }
    }
    plain.write(input[i]);
    i++;
  }
  flushPlain();
  return spans;
}
