import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Loads the bundled study content (spec §5). Content ships inside the build;
/// nothing is fetched from kubernetes.io at runtime.
class ContentLoader {
  const ContentLoader(this.bundle, {this.root = 'assets/content'});

  final AssetBundle bundle;
  final String root;

  Future<dynamic> _json(String path) async =>
      jsonDecode(await bundle.loadString('$root/$path'));

  Future<ContentBundle> load() async {
    final manifest = ContentManifest.fromJson(await _json('manifest.json'));
    final curriculum = Curriculum.fromJson(await _json('domains.json'));
    final topics = await Future.wait([
      for (final id in manifest.topicIds)
        _json('topics/$id.json').then((raw) => Topic.fromJson(raw, '$id.json')),
    ]);
    final tests = await _json('practice_tests.json');
    final testList = (tests as Map<String, dynamic>)['tests'];
    if (testList is! List) {
      throw const FormatException('practice_tests.json.tests: expected list');
    }
    return ContentBundle(
      manifest: manifest,
      curriculum: curriculum,
      topics: topics,
      practiceTests: [
        for (var i = 0; i < testList.length; i++)
          PracticeTestDef.fromJson(testList[i], 'practice_tests.json.tests[$i]'),
      ],
    );
  }
}
