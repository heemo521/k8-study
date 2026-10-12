// Content invariants from spec §5.2. Every note, card and question must be
// traceable to an allow-listed documentation URL.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/content_loader.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/command_grading.dart';
import 'package:k8_study/engine/quiz.dart';
import 'package:k8_study/engine/practice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;

  setUpAll(() async {
    catalog = await ContentLoader(rootBundle).load();
  });

  test('catalog lists every subject directory', () {
    final onDisk = Directory('assets/content/subjects')
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    expect(catalog.subjects.map((s) => s.subject.id).toSet(), onDisk);
  });

  test('pubspec declares every subject asset directory', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final s in catalog.subjects) {
      final id = s.subject.id;
      expect(pubspec, contains('assets/content/subjects/$id/\n'), reason: id);
      expect(
        pubspec,
        contains('assets/content/subjects/$id/topics/'),
        reason: id,
      );
    }
  });

  test('ids are unique across all subjects', () {
    final topicIds = <String>{};
    final itemIds = <String>{};
    for (final t in catalog.subjects.expand((s) => s.topics)) {
      expect(topicIds.add(t.id), isTrue, reason: 'duplicate topic ${t.id}');
      for (final id in [
        ...t.sections.map((s) => s.id),
        ...t.flashcards.map((c) => c.id),
        ...t.questions.map((q) => q.id),
      ]) {
        expect(itemIds.add(id), isTrue, reason: 'duplicate id $id');
        expect(
          id.startsWith('${t.id}-'),
          isTrue,
          reason: '$id must be prefixed with "${t.id}-"',
        );
      }
    }
  });

  // Per-subject rules.
  void subjectTest(String name, void Function(ContentBundle content) body) {
    test(name, () {
      for (final content in catalog.subjects) {
        body(content);
      }
    });
  }

  subjectTest(
    'every section, card and question has an allow-listed source URL',
    (content) {
      for (final t in content.topics) {
        for (final (id, url) in [
          for (final s in t.sections) (s.id, s.sourceUrl),
          for (final c in t.flashcards) (c.id, c.sourceUrl),
          for (final q in t.questions) (q.id, q.sourceUrl),
        ]) {
          expect(
            content.subject.sourceAllowed(t.id, url),
            isTrue,
            reason: '$id → $url',
          );
        }
      }
    },
  );

  subjectTest('question shape rules', (content) {
    for (final q in content.allQuestions) {
      final correct = q.options.where((o) => o.correct).length;
      final optionIds = q.options.map((o) => o.id).toSet();
      expect(
        optionIds.length,
        q.options.length,
        reason: '${q.id}: duplicate option ids',
      );
      for (final o in q.options) {
        expect(o.text.trim(), isNotEmpty, reason: '${q.id}/${o.id} text');
        expect(
          o.explanation.trim(),
          isNotEmpty,
          reason: '${q.id}/${o.id} needs an explanation',
        );
      }
      switch (q.type) {
        case QuestionType.single:
          expect(correct, 1, reason: q.id);
          expect(q.options.length, inInclusiveRange(3, 5), reason: q.id);
        case QuestionType.multi:
          expect(correct, greaterThanOrEqualTo(2), reason: q.id);
          expect(q.options.length, inInclusiveRange(3, 5), reason: q.id);
          expect(
            q.stem,
            contains('Select $correct'),
            reason: '${q.id}: stem must say "Select $correct"',
          );
        case QuestionType.truefalse:
          expect(correct, 1, reason: q.id);
          expect(q.options.map((o) => o.text).toSet(), {
            'True',
            'False',
          }, reason: q.id);
        case QuestionType.command:
          expect(q.options, isEmpty, reason: q.id);
          expect(q.answers, isNotEmpty, reason: '${q.id}: needs answers');
          expect(
            q.explanation?.trim(),
            isNotEmpty,
            reason: '${q.id}: needs an explanation',
          );
          // Every accepted answer grades as correct, and a blank never does.
          for (final a in q.answers) {
            expect(isCorrect(q, {a}), isTrue, reason: '${q.id}: $a');
          }
          expect(isCorrect(q, {''}), isFalse, reason: q.id);
      }
      expect(q.difficulty, inInclusiveRange(1, 3), reason: q.id);
    }
  });

  subjectTest('lab rules', (content) {
    for (final t in content.topics) {
      for (final lab in t.labs) {
        expect(lab.id, startsWith('${t.id}-'), reason: lab.id);
        expect(
          content.subject.sourceAllowed(t.id, lab.sourceUrl),
          isTrue,
          reason: lab.id,
        );
        expect(lab.steps, isNotEmpty, reason: lab.id);
        for (final s in lab.steps) {
          expect(s.prompt.trim(), isNotEmpty, reason: lab.id);
          expect(s.explanation.trim(), isNotEmpty, reason: lab.id);
          for (final a in s.answers) {
            expect(
              commandMatches(a, s.answers),
              isTrue,
              reason: '${lab.id}: $a',
            );
          }
        }
      }
    }
  });

  subjectTest('domain and competency references resolve', (content) {
    for (final t in content.topics) {
      for (final d in t.domainIds) {
        expect(content.domain(d), isNotNull, reason: '${t.id} → domain $d');
      }
      for (final c in t.competencyIds) {
        expect(content.competencyText(c), isNotNull, reason: '${t.id} → $c');
      }
      for (final q in t.questions) {
        if (q.competencyId != null) {
          expect(
            content.competencyText(q.competencyId!),
            isNotNull,
            reason: '${q.id} → ${q.competencyId}',
          );
        }
      }
    }
    for (final test in content.practiceTests) {
      for (final d in test.filterDomainIds ?? const <String>[]) {
        expect(content.domain(d), isNotNull, reason: '${test.id} → $d');
      }
    }
  });

  subjectTest('volume minimums per topic', (content) {
    for (final t in content.topics) {
      expect(t.sections.length, inInclusiveRange(4, 8), reason: t.id);
      expect(t.flashcards.length, greaterThanOrEqualTo(10), reason: t.id);
      expect(t.questions.length, greaterThanOrEqualTo(12), reason: t.id);
      for (final s in t.sections) {
        expect(s.blocks, isNotEmpty, reason: s.id);
      }
    }
  });

  subjectTest('tables have at most 3 columns and rectangular rows', (content) {
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

  subjectTest('topic notes stay concise (≤ 1,500 words)', (content) {
    for (final t in content.topics) {
      var words = 0;
      for (final s in t.sections) {
        for (final b in s.blocks) {
          final text = switch (b) {
            ParagraphBlock(:final text) => text,
            BulletsBlock(:final items) => items.join(' '),
            CodeBlock(:final text) => text,
            CalloutBlock(:final text) => text,
            TableBlock(:final header, :final rows) => [
              ...header,
              ...rows.expand((r) => r),
            ].join(' '),
            DiagramBlock(:final description) => description,
          };
          words += text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        }
      }
      expect(words, lessThanOrEqualTo(1500), reason: '${t.id}: $words words');
    }
  });

  subjectTest('every practice test can be filled', (content) {
    for (final test in content.practiceTests) {
      expect(
        practicePool(test, content).length,
        greaterThanOrEqualTo(test.questionCount),
        reason: test.id,
      );
    }
  });

  subjectTest('exam domain weights sum to 100 (when a subject has weights)', (
    content,
  ) {
    final weighted = content.domains.where((d) => d.weightPercent != null);
    if (weighted.isEmpty) return;
    expect(weighted.fold<int>(0, (a, d) => a + d.weightPercent!), 100);
  });

  subjectTest('topic list matches the files on disk', (content) {
    final onDisk =
        Directory('assets/content/subjects/${content.subject.id}/topics')
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
            .toSet();
    expect(content.subject.topicIds.toSet(), onDisk);
    expect(
      content.subject.topicIds.length,
      onDisk.length,
      reason: 'no duplicate topic entries',
    );
  });

  subjectTest('prerequisites resolve and come earlier in study order', (
    content,
  ) {
    for (final t in content.topics) {
      for (final pre in t.prerequisites) {
        final p = content.topic(pre);
        expect(p, isNotNull, reason: '${t.id} → $pre');
        expect(
          content.topics.indexOf(p!),
          lessThan(content.topics.indexOf(t)),
          reason: '${t.id}: prerequisite $pre must be studied first',
        );
      }
    }
  });

  subjectTest('every competency is covered by at least one question', (
    content,
  ) {
    final covered = {for (final q in content.allQuestions) q.competencyId};
    for (final d in content.domains) {
      for (final c in d.competencies) {
        expect(
          covered,
          contains(c.id),
          reason: '${content.subject.id}: ${c.id}',
        );
      }
    }
  });
}
