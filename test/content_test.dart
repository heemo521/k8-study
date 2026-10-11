// Content invariants from spec §5.2. Every note, card and question must be
// traceable to an allow-listed documentation URL.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/content_loader.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/practice.dart';

const _allowedEverywhere = [
  'https://kubernetes.io/docs/',
  'https://minikube.sigs.k8s.io/docs/',
];

// Vendor docs are allowed only for the managed-k8s topic (spec §12.1).
const _vendorPrefixes = [
  'https://docs.aws.amazon.com/eks/',
  'https://cloud.google.com/kubernetes-engine/docs/',
  'https://learn.microsoft.com/en-us/azure/aks/',
];

bool _allowed(String topicId, String url) =>
    _allowedEverywhere.any(url.startsWith) ||
    (topicId == 'managed-k8s' && _vendorPrefixes.any(url.startsWith));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentLoader(rootBundle).load();
  });

  test('manifest lists exactly the topic files on disk', () {
    final onDisk = Directory('assets/content/topics')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toSet();
    expect(content.manifest.topicIds.toSet(), onDisk);
    expect(content.manifest.topicIds.length, onDisk.length,
        reason: 'no duplicate manifest entries');
  });

  test('ids are unique and prefixed with their topic id', () {
    final topicIds = <String>{};
    final itemIds = <String>{};
    for (final t in content.topics) {
      expect(topicIds.add(t.id), isTrue, reason: 'duplicate topic ${t.id}');
      for (final id in [
        ...t.sections.map((s) => s.id),
        ...t.flashcards.map((c) => c.id),
        ...t.questions.map((q) => q.id),
      ]) {
        expect(itemIds.add(id), isTrue, reason: 'duplicate id $id');
        expect(id.startsWith('${t.id}-'), isTrue,
            reason: '$id must be prefixed with "${t.id}-"');
      }
    }
  });

  test('every section, card and question has an allow-listed source URL', () {
    for (final t in content.topics) {
      for (final (id, url) in [
        for (final s in t.sections) (s.id, s.sourceUrl),
        for (final c in t.flashcards) (c.id, c.sourceUrl),
        for (final q in t.questions) (q.id, q.sourceUrl),
      ]) {
        expect(_allowed(t.id, url), isTrue, reason: '$id → $url');
      }
    }
  });

  test('question shape rules', () {
    for (final q in content.allQuestions) {
      final correct = q.options.where((o) => o.correct).length;
      final optionIds = q.options.map((o) => o.id).toSet();
      expect(optionIds.length, q.options.length,
          reason: '${q.id}: duplicate option ids');
      for (final o in q.options) {
        expect(o.text.trim(), isNotEmpty, reason: '${q.id}/${o.id} text');
        expect(o.explanation.trim(), isNotEmpty,
            reason: '${q.id}/${o.id} needs an explanation');
      }
      switch (q.type) {
        case QuestionType.single:
          expect(correct, 1, reason: q.id);
          expect(q.options.length, inInclusiveRange(3, 5), reason: q.id);
        case QuestionType.multi:
          expect(correct, greaterThanOrEqualTo(2), reason: q.id);
          expect(q.options.length, inInclusiveRange(3, 5), reason: q.id);
          expect(q.stem, contains('Select $correct'),
              reason: '${q.id}: stem must say "Select $correct"');
        case QuestionType.truefalse:
          expect(correct, 1, reason: q.id);
          expect(q.options.map((o) => o.text).toSet(), {'True', 'False'},
              reason: q.id);
      }
      expect(q.difficulty, inInclusiveRange(1, 3), reason: q.id);
    }
  });

  test('domain and competency references resolve', () {
    for (final t in content.topics) {
      for (final d in t.domainIds) {
        expect(content.domain(d), isNotNull, reason: '${t.id} → domain $d');
      }
      for (final c in t.competencyIds) {
        expect(content.competencyText(c), isNotNull, reason: '${t.id} → $c');
      }
      for (final q in t.questions) {
        if (q.competencyId != null) {
          expect(content.competencyText(q.competencyId!), isNotNull,
              reason: '${q.id} → ${q.competencyId}');
        }
      }
    }
    for (final test in content.practiceTests) {
      for (final d in test.filterDomainIds ?? const <String>[]) {
        expect(content.domain(d), isNotNull, reason: '${test.id} → $d');
      }
    }
  });

  test('volume minimums per topic', () {
    for (final t in content.topics) {
      expect(t.sections.length, inInclusiveRange(4, 8), reason: t.id);
      expect(t.flashcards.length, greaterThanOrEqualTo(10), reason: t.id);
      expect(t.questions.length, greaterThanOrEqualTo(12), reason: t.id);
      for (final s in t.sections) {
        expect(s.blocks, isNotEmpty, reason: s.id);
      }
    }
  });

  test('tables have at most 3 columns and rectangular rows', () {
    for (final t in content.topics) {
      for (final s in t.sections) {
        for (final b in s.blocks.whereType<TableBlock>()) {
          expect(b.header.length, inInclusiveRange(2, 3), reason: s.id);
          for (final row in b.rows) {
            expect(row.length, b.header.length, reason: s.id);
          }
        }
      }
    }
  });

  test('topic notes stay concise (≤ 1,500 words)', () {
    for (final t in content.topics) {
      var words = 0;
      for (final s in t.sections) {
        for (final b in s.blocks) {
          final text = switch (b) {
            ParagraphBlock(:final text) => text,
            BulletsBlock(:final items) => items.join(' '),
            CodeBlock(:final text) => text,
            CalloutBlock(:final text) => text,
            TableBlock(:final header, :final rows) =>
              [...header, ...rows.expand((r) => r)].join(' '),
          };
          words += text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        }
      }
      expect(words, lessThanOrEqualTo(1500), reason: '${t.id}: $words words');
    }
  });

  test('every practice test can be filled', () {
    for (final test in content.practiceTests) {
      expect(practicePool(test, content).length,
          greaterThanOrEqualTo(test.questionCount),
          reason: test.id);
    }
  });

  test('exam domain weights sum to 100', () {
    final sum = content.curriculum.domains
        .where((d) => d.isExamDomain)
        .fold<int>(0, (a, d) => a + d.weightPercent!);
    expect(sum, 100);
  });
}
