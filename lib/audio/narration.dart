import '../content/models.dart';
import 'speech.dart';

/// Spoken text for a topic's notes: one group per section. Markup is
/// stripped, code is announced rather than read, table rows are read as
/// "header: value" pairs and diagrams read their walkthrough.
List<SpeechItem> narrateTopic(Topic topic) => [
  for (var i = 0; i < topic.sections.length; i++)
    for (final chunk in _sectionChunks(topic.sections[i], i))
      SpeechItem(i, chunk),
];

Iterable<String> _sectionChunks(NoteSection section, int index) sync* {
  yield 'Section ${index + 1}. ${_plain(section.heading)}.';
  for (final block in section.blocks) {
    final text = switch (block) {
      ParagraphBlock(:final text) => text,
      BulletsBlock(:final items) => items.map(_sentence).join(' '),
      CodeBlock() => 'There is a code example on screen.',
      CalloutBlock(:final kind, :final text) =>
        '${switch (kind) {
          CalloutKind.key => 'Key point.',
          CalloutKind.exam => 'Exam tip.',
          CalloutKind.warn => 'Warning.',
          CalloutKind.story => 'Port story.',
        }} $text',
      TableBlock(:final header, :final rows) => [
        for (final row in rows)
          _sentence(
            [
              for (var c = 0; c < row.length && c < header.length; c++)
                '${header[c]}: ${row[c]}',
            ].join('; '),
          ),
      ].join(' '),
      SceneBlock(:final caption) => 'Picture. ${_sentence(caption)}',
      DiagramBlock(:final title, :final steps) => [
        'Diagram: ${_sentence(title)}',
        for (final s in steps) _sentence(s.text),
      ].join(' '),
    };
    yield* _chunks(_plain(text));
  }
}

/// Removes inline markup and reads placeholders naturally.
String _plain(String s) => s
    .replaceAll('**', '')
    .replaceAll('`', '')
    .replaceAllMapped(RegExp(r'<([^<>]+)>'), (m) => m[1]!)
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _sentence(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return RegExp(r'[.!?:]$').hasMatch(t) ? t : '$t.';
}

/// Splits [text] into sentence-sized chunks of at most ~[max] characters.
/// Browsers cut off very long utterances, and short chunks make pause and
/// skip responsive.
Iterable<String> _chunks(String text, {int max = 220}) sync* {
  if (text.isEmpty) return;
  final sentences = RegExp(r'[^.!?]+[.!?]+(?=\s|$)|[^.!?]+$')
      .allMatches(text)
      .map((m) => m[0]!.trim())
      .where((s) => s.isNotEmpty);
  var buffer = '';
  for (final s in sentences) {
    if (buffer.isNotEmpty && buffer.length + 1 + s.length > max) {
      yield buffer;
      buffer = '';
    }
    if (s.length > max) {
      // A single very long sentence: break at commas or spaces.
      var rest = s;
      while (rest.length > max) {
        var cut = rest.lastIndexOf(RegExp(r'[,;] '), max);
        if (cut < max ~/ 2) cut = rest.lastIndexOf(' ', max);
        if (cut <= 0) cut = max;
        yield rest.substring(0, cut + 1).trim();
        rest = rest.substring(cut + 1).trim();
      }
      buffer = rest;
    } else {
      buffer = buffer.isEmpty ? s : '$buffer $s';
    }
  }
  if (buffer.isNotEmpty) yield buffer;
}
