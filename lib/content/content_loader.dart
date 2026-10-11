import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Loads the bundled study content (spec §5, docs/ADDING_CONTENT.md).
/// Content ships inside the build; nothing is fetched at runtime.
class ContentLoader {
  const ContentLoader(this.bundle, {this.root = 'assets/content'});

  final AssetBundle bundle;
  final String root;

  Future<dynamic> _json(String path) async =>
      jsonDecode(await bundle.loadString('$root/$path'));

  Future<Catalog> load() async {
    final catalog = await _json('catalog.json') as Map<String, dynamic>;
    final ids = catalog['subjects'];
    if (ids is! List || ids.isEmpty) {
      throw const FormatException('catalog.json.subjects: non-empty list');
    }
    return Catalog(await Future.wait([
      for (final id in ids) loadSubject(id as String),
    ]));
  }

  Future<ContentBundle> loadSubject(String id) async {
    final dir = 'subjects/$id';
    final subject =
        SubjectInfo.fromJson(await _json('$dir/subject.json'), '$id/subject.json');
    final topics = await Future.wait([
      for (final t in subject.topicIds)
        _json('$dir/topics/$t.json').then((raw) => Topic.fromJson(raw, '$t.json')),
    ]);
    final tests = await _json('$dir/practice_tests.json') as Map<String, dynamic>;
    final testList = tests['tests'];
    if (testList is! List) {
      throw FormatException('$id/practice_tests.json.tests: expected list');
    }
    return ContentBundle(
      subject: subject,
      topics: topics,
      practiceTests: [
        for (var i = 0; i < testList.length; i++)
          PracticeTestDef.fromJson(testList[i], '$id/practice_tests.json[$i]'),
      ],
    );
  }
}
