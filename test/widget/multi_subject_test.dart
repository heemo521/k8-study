// The real catalog ships a second subject (Docker): switching works end to
// end and progress stays separate per subject.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switch to Docker, study it, switch back', (tester) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    final docker = h.catalog.subject('docker');
    expect(docker.subject.id, 'docker', reason: 'catalog ships Docker');
    final k8sCount = h.content.topics.length;

    await tapKey(tester, 'subject-switcher');
    await tapKey(tester, 'subject-docker');
    expect(h.progress.subjectId, 'docker');
    expect(
      find.text('0 of ${docker.topics.length} topics complete'),
      findsOneWidget,
    );
    expect(find.textContaining('Start here · Topic 1 of'), findsOneWidget);
    expect(find.text(docker.topics.first.title), findsWidgets);

    // Study a Docker topic: Kubernetes progress is unaffected.
    final t = docker.topics.first;
    for (final s in t.sections) {
      h.progress.markSectionRead(t.id, s.id);
    }
    h.progress.recordQuiz(t.id, 100, {});
    await tester.pumpAndSettle();
    expect(
      find.text('1 of ${docker.topics.length} topics complete'),
      findsOneWidget,
    );

    // About shows the Docker attribution alongside Kubernetes'.
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attribution-docker')), findsOneWidget);

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'subject-switcher');
    await tapKey(tester, 'subject-kubernetes');
    expect(find.text('0 of $k8sCount topics complete'), findsOneWidget);
  });

  testWidgets('quiz result for another subject\'s topic shows a message, '
      'not a crash', (tester) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(tester);
    h.progress.subjectId = 'docker';
    await tester.pumpAndSettle();
    await pumpApp(
      tester,
      initialLocation: '/topic/pods/quiz/result',
      prefs: {'k8s.settings': '{"subjectId":"docker"}'},
    );
    expect(tester.takeException(), isNull);
    expect(find.text('No recent quiz result to show.'), findsOneWidget);
  });
}
