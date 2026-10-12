// Onboarding smoke test: a subject freshly scaffolded with
// `tool/new_subject.py` (no topics yet) must load and render every screen.
// CI scaffolds one and sets ONBOARDING_SUBJECT; locally it is skipped.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'multi_subject_test.dart' show tapKey;
import 'test_app.dart';

void main() {
  final id = Platform.environment['ONBOARDING_SUBJECT'];
  testWidgets('a freshly scaffolded subject renders every tab', (tester) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    await tapKey(tester, 'subject-switcher');
    await tapKey(tester, 'subject-$id');
    expect(h.progress.subjectId, id);
    for (final tab in ['Practice', 'Progress', 'About', 'Learn']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, skip: id == null);
}
