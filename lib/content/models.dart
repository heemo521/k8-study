/// Content models. These mirror the JSON schemas in spec/SPEC.md §5.1.
///
/// `fromJson` is strict: a missing or mistyped field throws a
/// [FormatException] that names the offending path, so broken content fails
/// loudly in tests rather than silently in the app.
library;

T _field<T>(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException('$path.$key: expected $T, got ${value.runtimeType}');
}

T? _optional<T>(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value == null || value is T) return value as T?;
  throw FormatException('$path.$key: expected $T?, got ${value.runtimeType}');
}

List<T> _list<T>(
  Map<String, dynamic> json,
  String key,
  String path,
  T Function(dynamic item, String itemPath) parse,
) {
  final raw = _field<List<dynamic>>(json, key, path);
  return [for (var i = 0; i < raw.length; i++) parse(raw[i], '$path.$key[$i]')];
}

Map<String, dynamic> _map(dynamic value, String path) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$path: expected object, got ${value.runtimeType}');
}

String _string(dynamic value, String path) {
  if (value is String) return value;
  throw FormatException('$path: expected String, got ${value.runtimeType}');
}

class Competency {
  const Competency({required this.id, required this.text});

  final String id;
  final String text;

  factory Competency.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return Competency(
      id: _field<String>(json, 'id', path),
      text: _field<String>(json, 'text', path),
    );
  }
}

class Domain {
  const Domain({
    required this.id,
    required this.title,
    required this.weightPercent,
    required this.isExamDomain,
    required this.competencies,
  });

  final String id;
  final String title;

  /// CKA exam weight. Null for the app-only Foundations domain.
  final int? weightPercent;
  final bool isExamDomain;
  final List<Competency> competencies;

  factory Domain.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return Domain(
      id: _field<String>(json, 'id', path),
      title: _field<String>(json, 'title', path),
      weightPercent: _optional<int>(json, 'weightPercent', path),
      isExamDomain: _field<bool>(json, 'isExamDomain', path),
      competencies: _list(json, 'competencies', path, Competency.fromJson),
    );
  }
}

class Curriculum {
  const Curriculum({
    required this.source,
    required this.examK8sVersion,
    required this.checkedAt,
    required this.domains,
  });

  final String source;
  final String examK8sVersion;
  final String checkedAt;
  final List<Domain> domains;

  factory Curriculum.fromJson(dynamic raw) {
    const path = 'domains.json';
    final json = _map(raw, path);
    return Curriculum(
      source: _field<String>(json, 'source', path),
      examK8sVersion: _field<String>(json, 'examK8sVersion', path),
      checkedAt: _field<String>(json, 'checkedAt', path),
      domains: _list(json, 'domains', path, Domain.fromJson),
    );
  }
}

/// A typed content block inside a note section (spec §5.3).
sealed class NoteBlock {
  const NoteBlock();

  factory NoteBlock.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    final type = _field<String>(json, 'type', path);
    switch (type) {
      case 'p':
        return ParagraphBlock(_field<String>(json, 'text', path));
      case 'bullets':
        return BulletsBlock(_list(json, 'items', path, _string));
      case 'code':
        return CodeBlock(
          lang: _field<String>(json, 'lang', path),
          text: _field<String>(json, 'text', path),
        );
      case 'callout':
        final kind = _field<String>(json, 'kind', path);
        return CalloutBlock(
          kind: CalloutKind.values.firstWhere(
            (k) => k.name == kind,
            orElse: () => throw FormatException('$path.kind: unknown "$kind"'),
          ),
          text: _field<String>(json, 'text', path),
        );
      case 'table':
        return TableBlock(
          header: _list(json, 'header', path, _string),
          rows: _list(
            json,
            'rows',
            path,
            (row, rowPath) {
              if (row is! List) {
                throw FormatException('$rowPath: expected list');
              }
              return [
                for (var i = 0; i < row.length; i++)
                  _string(row[i], '$rowPath[$i]'),
              ];
            },
          ),
        );
      default:
        throw FormatException('$path.type: unknown block type "$type"');
    }
  }
}

class ParagraphBlock extends NoteBlock {
  const ParagraphBlock(this.text);
  final String text;
}

class BulletsBlock extends NoteBlock {
  const BulletsBlock(this.items);
  final List<String> items;
}

class CodeBlock extends NoteBlock {
  const CodeBlock({required this.lang, required this.text});
  final String lang;
  final String text;
}

enum CalloutKind { key, exam, warn }

class CalloutBlock extends NoteBlock {
  const CalloutBlock({required this.kind, required this.text});
  final CalloutKind kind;
  final String text;
}

class TableBlock extends NoteBlock {
  const TableBlock({required this.header, required this.rows});
  final List<String> header;
  final List<List<String>> rows;
}

class NoteSection {
  const NoteSection({
    required this.id,
    required this.heading,
    required this.sourceUrl,
    required this.sourceTitle,
    required this.blocks,
  });

  final String id;
  final String heading;
  final String sourceUrl;
  final String sourceTitle;
  final List<NoteBlock> blocks;

  factory NoteSection.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return NoteSection(
      id: _field<String>(json, 'id', path),
      heading: _field<String>(json, 'heading', path),
      sourceUrl: _field<String>(json, 'sourceUrl', path),
      sourceTitle: _field<String>(json, 'sourceTitle', path),
      blocks: _list(json, 'blocks', path, NoteBlock.fromJson),
    );
  }
}

class Flashcard {
  const Flashcard({
    required this.id,
    required this.topicId,
    required this.front,
    required this.back,
    required this.sourceUrl,
  });

  final String id;
  final String topicId;
  final String front;
  final String back;
  final String sourceUrl;

  static Flashcard Function(dynamic, String) parser(String topicId) =>
      (raw, path) {
        final json = _map(raw, path);
        return Flashcard(
          id: _field<String>(json, 'id', path),
          topicId: topicId,
          front: _field<String>(json, 'front', path),
          back: _field<String>(json, 'back', path),
          sourceUrl: _field<String>(json, 'sourceUrl', path),
        );
      };
}

enum QuestionType { single, multi, truefalse }

class AnswerOption {
  const AnswerOption({
    required this.id,
    required this.text,
    required this.correct,
    required this.explanation,
  });

  final String id;
  final String text;
  final bool correct;
  final String explanation;

  factory AnswerOption.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return AnswerOption(
      id: _field<String>(json, 'id', path),
      text: _field<String>(json, 'text', path),
      correct: _field<bool>(json, 'correct', path),
      explanation: _field<String>(json, 'explanation', path),
    );
  }
}

class Question {
  const Question({
    required this.id,
    required this.topicId,
    required this.type,
    required this.stem,
    required this.options,
    required this.sourceUrl,
    required this.difficulty,
    this.competencyId,
  });

  final String id;
  final String topicId;
  final QuestionType type;
  final String stem;
  final List<AnswerOption> options;
  final String sourceUrl;
  final int difficulty;
  final String? competencyId;

  Set<String> get correctIds =>
      {for (final o in options) if (o.correct) o.id};

  static Question Function(dynamic, String) parser(String topicId) =>
      (raw, path) {
        final json = _map(raw, path);
        final type = _field<String>(json, 'type', path);
        return Question(
          id: _field<String>(json, 'id', path),
          topicId: topicId,
          type: QuestionType.values.firstWhere(
            (t) => t.name == type,
            orElse: () => throw FormatException('$path.type: unknown "$type"'),
          ),
          stem: _field<String>(json, 'stem', path),
          options: _list(json, 'options', path, AnswerOption.fromJson),
          sourceUrl: _field<String>(json, 'sourceUrl', path),
          difficulty: _field<int>(json, 'difficulty', path),
          competencyId: _optional<String>(json, 'competencyId', path),
        );
      };
}

class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.summary,
    required this.order,
    required this.domainIds,
    required this.competencyIds,
    required this.estMinutes,
    required this.reviewedAt,
    required this.sections,
    required this.flashcards,
    required this.questions,
  });

  final String id;
  final String title;
  final String summary;
  final int order;

  /// The first entry is the primary domain, used for grouping and for the
  /// practice-test per-domain breakdown.
  final List<String> domainIds;
  final List<String> competencyIds;
  final int estMinutes;
  final String reviewedAt;
  final List<NoteSection> sections;
  final List<Flashcard> flashcards;
  final List<Question> questions;

  String get primaryDomainId => domainIds.first;

  /// Every source URL used by this topic, de-duplicated, in first-use order.
  List<String> get sourceUrls {
    final seen = <String>{};
    return [
      for (final url in [
        ...sections.map((s) => s.sourceUrl),
        ...flashcards.map((c) => c.sourceUrl),
        ...questions.map((q) => q.sourceUrl),
      ])
        if (seen.add(url)) url,
    ];
  }

  factory Topic.fromJson(dynamic raw, String file) {
    final json = _map(raw, file);
    final id = _field<String>(json, 'id', file);
    final domainIds = _list(json, 'domainIds', file, _string);
    if (domainIds.isEmpty) {
      throw FormatException('$file.domainIds: must not be empty');
    }
    return Topic(
      id: id,
      title: _field<String>(json, 'title', file),
      summary: _field<String>(json, 'summary', file),
      order: _field<int>(json, 'order', file),
      domainIds: domainIds,
      competencyIds: _list(json, 'competencyIds', file, _string),
      estMinutes: _field<int>(json, 'estMinutes', file),
      reviewedAt: _field<String>(json, 'reviewedAt', file),
      sections: _list(json, 'sections', file, NoteSection.fromJson),
      flashcards: _list(json, 'flashcards', file, Flashcard.parser(id)),
      questions: _list(json, 'questions', file, Question.parser(id)),
    );
  }
}

enum PracticeWeighting { uniform, domain }

class PracticeTestDef {
  const PracticeTestDef({
    required this.id,
    required this.title,
    required this.description,
    required this.questionCount,
    required this.timeLimitMinutes,
    required this.filterDomainIds,
    required this.weighting,
  });

  final String id;
  final String title;
  final String description;
  final int questionCount;
  final int timeLimitMinutes;

  /// Null means every question in the bank.
  final List<String>? filterDomainIds;
  final PracticeWeighting weighting;

  factory PracticeTestDef.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    final filter = _map(json['filter'], '$path.filter');
    final rawDomains = filter['domainIds'];
    final weighting = _field<String>(json, 'weighting', path);
    return PracticeTestDef(
      id: _field<String>(json, 'id', path),
      title: _field<String>(json, 'title', path),
      description: _field<String>(json, 'description', path),
      questionCount: _field<int>(json, 'questionCount', path),
      timeLimitMinutes: _field<int>(json, 'timeLimitMinutes', path),
      filterDomainIds: rawDomains == null
          ? null
          : _list(filter, 'domainIds', '$path.filter', _string),
      weighting: PracticeWeighting.values.firstWhere(
        (w) => w.name == weighting,
        orElse: () => throw FormatException('$path.weighting: "$weighting"'),
      ),
    );
  }
}

class ContentManifest {
  const ContentManifest({
    required this.contentVersion,
    required this.reviewedAt,
    required this.topicIds,
  });

  final int contentVersion;
  final String reviewedAt;
  final List<String> topicIds;

  factory ContentManifest.fromJson(dynamic raw) {
    const path = 'manifest.json';
    final json = _map(raw, path);
    return ContentManifest(
      contentVersion: _field<int>(json, 'contentVersion', path),
      reviewedAt: _field<String>(json, 'reviewedAt', path),
      topicIds: _list(json, 'topics', path, _string),
    );
  }
}

/// Everything the app knows about its study content, with lookups.
class ContentBundle {
  ContentBundle({
    required this.manifest,
    required this.curriculum,
    required this.topics,
    required this.practiceTests,
  })  : _topicsById = {for (final t in topics) t.id: t},
        _domainsById = {for (final d in curriculum.domains) d.id: d},
        _sourceTitles = {
          for (final t in topics)
            for (final s in t.sections) s.sourceUrl: s.sourceTitle,
        };

  final ContentManifest manifest;
  final Curriculum curriculum;
  final List<Topic> topics;
  final List<PracticeTestDef> practiceTests;
  final Map<String, Topic> _topicsById;
  final Map<String, Domain> _domainsById;
  final Map<String, String> _sourceTitles;

  /// Page title for a source URL, taken from the note sections citing it.
  String? sourceTitle(String url) => _sourceTitles[url];

  Topic? topic(String id) => _topicsById[id];
  Domain? domain(String id) => _domainsById[id];

  PracticeTestDef? practiceTest(String id) {
    for (final t in practiceTests) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Domains in display order: Foundations first, then exam domains by weight.
  List<Domain> get domainsInDisplayOrder {
    final list = [...curriculum.domains];
    list.sort((a, b) {
      if (a.isExamDomain != b.isExamDomain) return a.isExamDomain ? 1 : -1;
      return (b.weightPercent ?? 0).compareTo(a.weightPercent ?? 0);
    });
    return list;
  }

  /// Topics whose primary domain is [domainId], in their declared order.
  List<Topic> topicsForDomain(String domainId) =>
      topics.where((t) => t.primaryDomainId == domainId).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  Iterable<Question> get allQuestions => topics.expand((t) => t.questions);

  String? competencyText(String competencyId) {
    for (final d in curriculum.domains) {
      for (final c in d.competencies) {
        if (c.id == competencyId) return c.text;
      }
    }
    return null;
  }
}
