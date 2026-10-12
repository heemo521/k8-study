import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../audio_test.dart' show FakeSpeechEngine;
import 'test_app.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('read-aloud player fits 360px at ${scale}x text', (
      tester,
    ) async {
      await setPhoneViewport(tester, size: const Size(360, 740));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        tester,
        initialLocation: '/topic/namespaces/notes',
        speech: FakeSpeechEngine(),
      );
      await tester.tap(find.byKey(const ValueKey('listen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('listen-bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
