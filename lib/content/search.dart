/// Plain-text search over a subject's topics, note sections and flashcards.
library;

import 'models.dart';

enum SearchKind { topic, section, flashcard }

class SearchHit {
  const SearchHit({
    required this.kind,
    required this.topic,
    required this.title,
    required this.snippet,
    this.sectionId,
  });

  final SearchKind kind;
  final Topic topic;
  final String title;
  final String snippet;
  final String? sectionId;
}

String _plain(String s) => s.replaceAll('**', '').replaceAll('`', '');

String blockText(NoteBlock b) => switch (b) {
      ParagraphBlock(:final text) => text,
      BulletsBlock(:final items) => items.join(' · '),
      CodeBlock(:final text) => text,
      CalloutBlock(:final text) => text,
      TableBlock(:final header, :final rows) =>
        [header.join(' | '), for (final r in rows) r.join(' | ')].join(' · '),
    };

/// ~[width]-char window around the first match of [needle] in [text].
String snippetAround(String text, String needle, {int width = 110}) {
  final plain = _plain(text).replaceAll('\n', ' ');
  final i = plain.toLowerCase().indexOf(needle.toLowerCase());
  if (i < 0) return plain.length <= width ? plain : '${plain.substring(0, width)}…';
  final start = (i - width ~/ 3).clamp(0, plain.length);
  final end = (start + width).clamp(0, plain.length);
  return '${start > 0 ? '…' : ''}${plain.substring(start, end)}${end < plain.length ? '…' : ''}';
}

/// Results ranked: topic titles, then section headings, then section body,
/// then flashcards. Every whitespace-separated term must match.
List<SearchHit> search(ContentBundle content, String query, {int limit = 50}) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 2)
      .toList();
  if (terms.isEmpty) return const [];
  bool matches(String text) {
    final t = _plain(text).toLowerCase();
    return terms.every(t.contains);
  }

  final topicHits = <SearchHit>[];
  final headingHits = <SearchHit>[];
  final bodyHits = <SearchHit>[];
  final cardHits = <SearchHit>[];
  for (final topic in content.topics) {
    if (matches('${topic.title} ${topic.summary}')) {
      topicHits.add(SearchHit(
          kind: SearchKind.topic,
          topic: topic,
          title: topic.title,
          snippet: topic.summary));
    }
    for (final s in topic.sections) {
      final body = s.blocks.map(blockText).join(' ');
      if (matches(s.heading)) {
        headingHits.add(SearchHit(
            kind: SearchKind.section,
            topic: topic,
            sectionId: s.id,
            title: s.heading,
            snippet: snippetAround(body, terms.first)));
      } else if (matches('${s.heading} $body')) {
        bodyHits.add(SearchHit(
            kind: SearchKind.section,
            topic: topic,
            sectionId: s.id,
            title: s.heading,
            snippet: snippetAround(body, terms.first)));
      }
    }
    for (final c in topic.flashcards) {
      if (matches('${c.front} ${c.back}')) {
        cardHits.add(SearchHit(
            kind: SearchKind.flashcard,
            topic: topic,
            title: _plain(c.front),
            snippet: _plain(c.back)));
      }
    }
  }
  return [...topicHits, ...headingHits, ...bodyHits, ...cardHits]
      .take(limit)
      .toList();
}
