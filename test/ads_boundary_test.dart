// Spec §9.1/§9.2: screens talk to AdsService only, no ad SDKs anywhere in the
// web build, and no real ad unit / publisher IDs in the repo.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const textExtensions = ['.dart', '.html', '.js', '.json', '.yaml', '.md', '.mjs'];

Iterable<File> dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('screens never import ad implementations or SDKs', () {
    final banned = RegExp(
        r'''import\s+['"](package:google_mobile_ads|package:[^'"]*adsense|[^'"]*ads/impl/)''');
    for (final f in dartFiles('lib/screens')) {
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('no ad SDK dependency in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('google_mobile_ads')));
  });

  test('web build never loads adsbygoogle.js', () {
    for (final f in Directory('web').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.html') && !f.path.endsWith('.js')) continue;
      expect(f.readAsStringSync(), isNot(contains('adsbygoogle')), reason: f.path);
    }
  });

  test('only the obviously-fake publisher id appears in source', () {
    final pubId = RegExp(r'ca-pub-\d+');
    final appId = RegExp(r'ca-app-pub-\d+');
    for (final dir in ['lib', 'web', 'tool']) {
      if (!Directory(dir).existsSync()) continue;
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!textExtensions.any(f.path.endsWith)) continue;
        final text = f.readAsStringSync();
        for (final m in pubId.allMatches(text)) {
          expect(m.group(0), 'ca-pub-0000000000000000', reason: f.path);
        }
        expect(appId.hasMatch(text), isFalse, reason: f.path);
      }
    }
  });
}
