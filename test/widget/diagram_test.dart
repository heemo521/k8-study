import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/widgets/diagram_view.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

Map<String, dynamic> _diagram({
  List<Map<String, dynamic>>? nodes,
  List<Map<String, dynamic>>? edges,
  List<Map<String, dynamic>>? steps,
}) => {
  'type': 'diagram',
  'title': 'T',
  'width': 10,
  'height': 4,
  'nodes':
      nodes ??
      [
        {'id': 'a', 'label': 'A', 'x': 0, 'y': 0, 'w': 3, 'h': 1},
        {'id': 'b', 'label': 'B', 'x': 5, 'y': 0, 'w': 3, 'h': 1},
      ],
  'edges':
      edges ??
      [
        {'from': 'a', 'to': 'b', 'flow': true},
      ],
  'steps':
      steps ??
      [
        {
          'text': 'First A',
          'highlight': ['a'],
        },
        {
          'text': 'Then B',
          'highlight': ['a', 'b'],
        },
      ],
};

void main() {
  test('diagram blocks parse and reject bad references', () {
    final block = NoteBlock.fromJson(_diagram(), 'd') as DiagramBlock;
    expect(block.nodes, hasLength(2));
    expect(block.edges.single.flow, isTrue);
    expect(block.description, 'T. First A. Then B');

    expect(
      () => NoteBlock.fromJson(
        _diagram(
          edges: [
            {'from': 'a', 'to': 'zzz'},
          ],
        ),
        'd',
      ),
      throwsFormatException,
    );
    expect(
      () => NoteBlock.fromJson(
        _diagram(
          nodes: [
            {'id': 'a', 'label': 'A', 'x': 9, 'y': 0, 'w': 3, 'h': 1},
          ],
          edges: [],
          steps: [],
        ),
        'd',
      ),
      throwsFormatException,
    );
    expect(
      () => NoteBlock.fromJson(
        _diagram(
          steps: [
            {
              'text': 'x',
              'highlight': ['nope'],
            },
          ],
        ),
        'd',
      ),
      throwsFormatException,
    );
  });

  testWidgets('walkthrough steps forward and back', (tester) async {
    DiagramView.flowAnimation = false;
    final block = NoteBlock.fromJson(_diagram(), 'd') as DiagramBlock;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DiagramView(block: block)),
        ),
      ),
    );
    expect(find.text('Overview'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('diagram-next')));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('First A'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('diagram-next')));
    await tester.pumpAndSettle();
    expect(find.text('Then B'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('diagram-prev')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diagram-prev')));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
  });

  testWidgets('architecture notes show their diagram', (tester) async {
    await setPhoneViewport(tester);
    await pumpApp(tester, initialLocation: '/topic/architecture/notes');
    expect(find.byType(DiagramView), findsOneWidget);
    expect(find.text('How the components talk'), findsOneWidget);
  });
}
