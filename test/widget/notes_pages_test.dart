import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/widgets/diagram_view.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  setUp(() => DiagramView.flowAnimation = false);
  tearDown(() => DiagramView.flowAnimation = true);

  test('scene blocks parse and reject unknown scenes', () {
    final block = NoteBlock.fromJson({
      'type': 'scene',
      'scene': 'port-welcome',
      'caption': 'C',
    }, 's') as SceneBlock;
    expect(block.scene, PortScene.welcome);
    expect(
      () => NoteBlock.fromJson({
        'type': 'scene',
        'scene': 'nope',
        'caption': 'C',
      }, 's'),
      throwsFormatException,
    );
  });

  testWidgets('notes show one section per page with Next and Back', (
    tester,
  ) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(
      tester,
      initialLocation: '/topic/what-is-k8s/notes',
    );
    final topic = h.content.topic('what-is-k8s')!;
    expect(find.text(topic.sections[0].heading), findsOneWidget);
    expect(find.text(topic.sections[1].heading), findsNothing);
    expect(find.byKey(const ValueKey('scene-port-welcome')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notes-next')));
    await tester.pumpAndSettle();
    expect(find.text(topic.sections[1].heading), findsOneWidget);
    expect(find.byKey(const ValueKey('scene-port-services')), findsOneWidget);
    expect(
      h.progress.readSections(topic.id),
      contains(topic.sections[0].id),
      reason: 'Next marks the page read',
    );

    await tester.tap(find.byKey(const ValueKey('notes-back')));
    await tester.pumpAndSettle();
    expect(find.text(topic.sections[0].heading), findsOneWidget);
  });

  testWidgets('a search hit opens on its own page', (tester) async {
    await setPhoneViewport(tester);
    await pumpApp(
      tester,
      initialLocation: '/topic/what-is-k8s/notes?section=what-is-k8s-glance',
    );
    expect(find.text('A cluster at a glance'), findsOneWidget);
    expect(find.byKey(const ValueKey('next-flashcards')), findsOneWidget);
  });

  testWidgets('every first-lesson page lays out at 360px with 200% text', (
    tester,
  ) async {
    await setPhoneViewport(tester, size: const Size(360, 740));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = await pumpApp(
      tester,
      initialLocation: '/topic/what-is-k8s/notes',
    );
    final pages = h.content.topic('what-is-k8s')!.sections.length;
    for (var i = 0; i < pages; i++) {
      expect(tester.takeException(), isNull, reason: 'page $i');
      if (i < pages - 1) {
        await tester.tap(find.byKey(const ValueKey('notes-next')));
        await tester.pumpAndSettle();
      }
    }
  });
}
