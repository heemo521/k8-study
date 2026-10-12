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

/// Exam the subject's domains map to (e.g. the CKA). Optional per subject.
class ExamInfo {
  const ExamInfo({
    required this.name,
    required this.title,
    required this.source,
    required this.examVersion,
    required this.checkedAt,
    required this.note,
  });

  final String name;
  final String title;
  final String source;
  final String examVersion;
  final String checkedAt;
  final String note;

  factory ExamInfo.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return ExamInfo(
      name: _field<String>(json, 'name', path),
      title: _field<String>(json, 'title', path),
      source: _field<String>(json, 'source', path),
      examVersion: _field<String>(json, 'examVersion', path),
      checkedAt: _field<String>(json, 'checkedAt', path),
      note: _field<String>(json, 'note', path),
    );
  }
}

class LinkRef {
  const LinkRef({required this.label, required this.url});

  final String label;
  final String url;

  factory LinkRef.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return LinkRef(
      label: _field<String>(json, 'label', path),
      url: _field<String>(json, 'url', path),
    );
  }
}

/// A licence/attribution or trademark statement shown on the About page.
class Notice {
  const Notice({required this.text, required this.links});

  final String text;
  final List<LinkRef> links;

  factory Notice.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return Notice(
      text: _field<String>(json, 'text', path),
      links: _list(json, 'links', path, LinkRef.fromJson),
    );
  }
}

/// A permitted source URL prefix, optionally limited to some topics.
class AllowedSource {
  const AllowedSource({required this.prefix, this.topicIds});

  final String prefix;
  final List<String>? topicIds;

  bool allows(String topicId, String url) =>
      url.startsWith(prefix) &&
      (topicIds == null || topicIds!.contains(topicId));

  factory AllowedSource.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return AllowedSource(
      prefix: _field<String>(json, 'prefix', path),
      topicIds: json['topics'] == null
          ? null
          : _list(json, 'topics', path, _string),
    );
  }
}

/// Subject-level metadata from `subjects/<id>/subject.json`.
class SubjectInfo {
  const SubjectInfo({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.contentVersion,
    required this.reviewedAt,
    required this.exam,
    required this.domains,
    required this.topicIds,
    required this.sourceAllowlist,
    required this.attributions,
    required this.trademarks,
  });

  final String id;
  final String title;
  final String tagline;
  final String description;
  final int contentVersion;
  final String reviewedAt;
  final ExamInfo? exam;
  final List<Domain> domains;

  /// Recommended study order.
  final List<String> topicIds;
  final List<AllowedSource> sourceAllowlist;
  final List<Notice> attributions;
  final List<Notice> trademarks;

  bool sourceAllowed(String topicId, String url) =>
      sourceAllowlist.any((a) => a.allows(topicId, url));

  factory SubjectInfo.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return SubjectInfo(
      id: _field<String>(json, 'id', path),
      title: _field<String>(json, 'title', path),
      tagline: _field<String>(json, 'tagline', path),
      description: _field<String>(json, 'description', path),
      contentVersion: _field<int>(json, 'contentVersion', path),
      reviewedAt: _field<String>(json, 'reviewedAt', path),
      exam: json['curriculum'] == null
          ? null
          : ExamInfo.fromJson(json['curriculum'], '$path.curriculum'),
      domains: _list(json, 'domains', path, Domain.fromJson),
      topicIds: _list(json, 'topics', path, _string),
      sourceAllowlist: _list(
        json,
        'sourceAllowlist',
        path,
        AllowedSource.fromJson,
      ),
      attributions: _list(json, 'attributions', path, Notice.fromJson),
      trademarks: _list(json, 'trademarks', path, Notice.fromJson),
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
          rows: _list(json, 'rows', path, (row, rowPath) {
            if (row is! List) {
              throw FormatException('$rowPath: expected list');
            }
            return [
              for (var i = 0; i < row.length; i++)
                _string(row[i], '$rowPath[$i]'),
            ];
          }),
        );
      case 'diagram':
        return DiagramBlock.fromJson(json, path);
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

/// [story] is the analogy narrative that opens a section (Port of Kube).
enum CalloutKind { key, exam, warn, story }

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

/// Visual role of a diagram box; the renderer maps each to a colour.
enum DiagramKind {
  control,
  worker,
  pod,
  service,
  storage,
  external,
  user,
  generic,
}

/// A box on the diagram grid. A [group] is drawn behind the other boxes as a
/// labelled container (e.g. a node or namespace).
class DiagramNode {
  const DiagramNode({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.kind,
    required this.group,
  });

  final String id;
  final String label;
  final double x, y, w, h;
  final DiagramKind kind;
  final bool group;

  factory DiagramNode.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    final kind = _optional<String>(json, 'kind', path) ?? 'generic';
    return DiagramNode(
      id: _field<String>(json, 'id', path),
      label: _field<String>(json, 'label', path),
      x: _field<num>(json, 'x', path).toDouble(),
      y: _field<num>(json, 'y', path).toDouble(),
      w: _field<num>(json, 'w', path).toDouble(),
      h: _field<num>(json, 'h', path).toDouble(),
      kind: DiagramKind.values.firstWhere(
        (k) => k.name == kind,
        orElse: () => throw FormatException('$path.kind: unknown "$kind"'),
      ),
      group: _optional<bool>(json, 'group', path) ?? false,
    );
  }
}

/// An arrow between two boxes. [flow] animates dots along it.
class DiagramEdge {
  const DiagramEdge({
    required this.from,
    required this.to,
    this.label,
    required this.flow,
  });

  final String from;
  final String to;
  final String? label;
  final bool flow;

  factory DiagramEdge.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return DiagramEdge(
      from: _field<String>(json, 'from', path),
      to: _field<String>(json, 'to', path),
      label: _optional<String>(json, 'label', path),
      flow: _optional<bool>(json, 'flow', path) ?? false,
    );
  }
}

/// One step of a walkthrough: a sentence and the boxes it is about.
class DiagramStep {
  const DiagramStep({required this.text, required this.highlight});

  final String text;
  final List<String> highlight;

  factory DiagramStep.fromJson(dynamic raw, String path) {
    final json = _map(raw, path);
    return DiagramStep(
      text: _field<String>(json, 'text', path),
      highlight: _list(json, 'highlight', path, _string),
    );
  }
}

/// A data-driven diagram on a [width] x [height] grid, with optional
/// step-by-step walkthrough.
class DiagramBlock extends NoteBlock {
  const DiagramBlock({
    required this.title,
    required this.width,
    required this.height,
    required this.nodes,
    required this.edges,
    required this.steps,
  });

  final String title;
  final double width;
  final double height;
  final List<DiagramNode> nodes;
  final List<DiagramEdge> edges;
  final List<DiagramStep> steps;

  /// Plain-text description: title, then each walkthrough step. Used for
  /// search, screen readers and read-aloud.
  String get description => [title, for (final s in steps) s.text].join('. ');

  DiagramNode? node(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  factory DiagramBlock.fromJson(Map<String, dynamic> json, String path) {
    final block = DiagramBlock(
      title: _field<String>(json, 'title', path),
      width: _field<num>(json, 'width', path).toDouble(),
      height: _field<num>(json, 'height', path).toDouble(),
      nodes: _list(json, 'nodes', path, DiagramNode.fromJson),
      edges: json.containsKey('edges')
          ? _list(json, 'edges', path, DiagramEdge.fromJson)
          : const [],
      steps: json.containsKey('steps')
          ? _list(json, 'steps', path, DiagramStep.fromJson)
          : const [],
    );
    final ids = <String>{};
    for (final n in block.nodes) {
      if (!ids.add(n.id)) {
        throw FormatException('$path.nodes: duplicate id "${n.id}"');
      }
      if (n.x < 0 ||
          n.y < 0 ||
          n.x + n.w > block.width ||
          n.y + n.h > block.height) {
        throw FormatException('$path.nodes.${n.id}: outside the grid');
      }
    }
    for (final e in block.edges) {
      if (!ids.contains(e.from) || !ids.contains(e.to)) {
        throw FormatException(
          '$path.edges: unknown node in ${e.from}->${e.to}',
        );
      }
    }
    for (final s in block.steps) {
      for (final id in s.highlight) {
        if (!ids.contains(id)) {
          throw FormatException('$path.steps: unknown node "$id"');
        }
      }
    }
    return block;
  }
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

  Set<String> get correctIds => {
    for (final o in options)
      if (o.correct) o.id,
  };

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
    this.prerequisites = const [],
  });

  final String id;
  final String title;
  final String summary;
  final int order;

  /// Topic ids recommended before this one.
  final List<String> prerequisites;

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
      prerequisites: json['prerequisites'] == null
          ? const []
          : _list(json, 'prerequisites', file, _string),
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

/// One subject's content (Kubernetes, Linux, …) with lookups.
class ContentBundle {
  ContentBundle({
    required this.subject,
    required List<Topic> topics,
    required this.practiceTests,
  }) : topics = [
         // Recommended study order from subject.json.
         for (final id in subject.topicIds)
           topics.firstWhere((t) => t.id == id),
       ],
       _topicsById = {for (final t in topics) t.id: t},
       _domainsById = {for (final d in subject.domains) d.id: d},
       _sourceTitles = {
         for (final t in topics)
           for (final s in t.sections) s.sourceUrl: s.sourceTitle,
       };

  final SubjectInfo subject;

  /// In recommended study order.
  final List<Topic> topics;
  final List<PracticeTestDef> practiceTests;
  final Map<String, Topic> _topicsById;
  final Map<String, Domain> _domainsById;
  final Map<String, String> _sourceTitles;

  List<Domain> get domains => subject.domains;
  ExamInfo? get exam => subject.exam;

  Topic? topic(String id) => _topicsById[id];
  Domain? domain(String id) => _domainsById[id];

  /// Page title for a source URL, taken from the note sections citing it.
  String? sourceTitle(String url) => _sourceTitles[url];

  PracticeTestDef? practiceTest(String id) {
    for (final t in practiceTests) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Domains in display order: non-exam domains first, then by exam weight.
  List<Domain> get domainsInDisplayOrder {
    final list = [...domains];
    list.sort((a, b) {
      if (a.isExamDomain != b.isExamDomain) return a.isExamDomain ? 1 : -1;
      return (b.weightPercent ?? 0).compareTo(a.weightPercent ?? 0);
    });
    return list;
  }

  /// Topics whose primary domain is [domainId], in study order.
  List<Topic> topicsForDomain(String domainId) =>
      topics.where((t) => t.primaryDomainId == domainId).toList();

  Iterable<Question> get allQuestions => topics.expand((t) => t.questions);
  Iterable<Flashcard> get allFlashcards => topics.expand((t) => t.flashcards);

  Question? question(String id) {
    for (final q in allQuestions) {
      if (q.id == id) return q;
    }
    return null;
  }

  Competency? competency(String competencyId) {
    for (final d in domains) {
      for (final c in d.competencies) {
        if (c.id == competencyId) return c;
      }
    }
    return null;
  }

  String? competencyText(String competencyId) => competency(competencyId)?.text;

  /// Domain owning [competencyId].
  Domain? domainOfCompetency(String competencyId) {
    for (final d in domains) {
      if (d.competencies.any((c) => c.id == competencyId)) return d;
    }
    return null;
  }
}

/// All shipped subjects, in catalog order.
class Catalog {
  Catalog(this.subjects) : assert(subjects.isNotEmpty);

  final List<ContentBundle> subjects;

  ContentBundle subject(String? id) => subjects.firstWhere(
    (s) => s.subject.id == id,
    orElse: () => subjects.first,
  );
}
