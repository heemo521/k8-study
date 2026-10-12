import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/audio/narration.dart';
import 'package:k8_study/audio/speech.dart';
import 'package:k8_study/content/content_loader.dart';
import 'package:k8_study/content/models.dart';

/// Records what would be spoken; [finish] completes the current utterance.
class FakeSpeechEngine implements SpeechEngine {
  final spoken = <String>[];
  void Function(bool ok)? _done;
  double? lastRate;

  @override
  bool get supported => true;

  @override
  void speak(
    String text, {
    required double rate,
    required void Function(bool ok) onDone,
  }) {
    spoken.add(text);
    lastRate = rate;
    _done = onDone;
  }

  @override
  void cancel() => _done = null;

  void finish({bool ok = true}) {
    final d = _done;
    _done = null;
    d?.call(ok);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;
  setUpAll(() async {
    content = (await ContentLoader(rootBundle).load()).subject('kubernetes');
  });

  test('narration: one group per section, plain text, short chunks', () {
    final topic = content.topic('architecture')!;
    final items = narrateTopic(topic);
    expect(items.map((i) => i.group).toSet(), {
      for (var i = 0; i < topic.sections.length; i++) i,
    });
    expect(items.first.text, startsWith('Section 1. '));
    for (final item in items) {
      expect(item.text, isNot(contains('**')));
      expect(item.text, isNot(contains('`')));
      expect(item.text.length, lessThanOrEqualTo(260));
    }
    // The diagram's walkthrough is read.
    expect(
      items.any((i) => i.text.contains('Diagram: How the components talk')),
      isTrue,
    );
  });

  test('narration announces code instead of reading it', () {
    final topic = content.topic('deployments')!;
    final text = narrateTopic(topic).map((i) => i.text).join(' ');
    expect(text, contains('There is a code example on screen.'));
    expect(text, isNot(contains('apiVersion: apps/v1')));
  });

  test('controller plays groups in order and reports finished groups', () {
    final engine = FakeSpeechEngine();
    final c = SpeechController(engine);
    final done = <int>[];
    c.onGroupDone = done.add;
    c.play(const [
      SpeechItem(0, 'a1'),
      SpeechItem(0, 'a2'),
      SpeechItem(1, 'b1'),
    ]);
    expect(c.status, SpeechStatus.playing);
    expect(c.group, 0);
    engine.finish();
    expect(engine.spoken, ['a1', 'a2']);
    expect(done, isEmpty);
    engine.finish();
    expect(done, [0]);
    expect(c.group, 1);
    engine.finish();
    expect(done, [0, 1]);
    expect(c.status, SpeechStatus.idle);
  });

  test('a failed utterance stops playback with an error', () {
    final engine = FakeSpeechEngine();
    final done = <int>[];
    final c = SpeechController(engine)
      ..onGroupDone = done.add
      ..play(const [SpeechItem(0, 'a'), SpeechItem(1, 'b')]);
    engine.finish(ok: false);
    expect(c.status, SpeechStatus.idle);
    expect(c.error, SpeechController.noVoiceMessage);
    expect(done, isEmpty);
    c.play(const [SpeechItem(0, 'a')]);
    expect(c.error, isNull);
  });

  test('pause restarts the chunk on resume; skip and rate', () {
    final engine = FakeSpeechEngine();
    final c = SpeechController(engine)
      ..play(const [
        SpeechItem(0, 'a1'),
        SpeechItem(1, 'b1'),
        SpeechItem(2, 'c1'),
      ]);
    c.pause();
    expect(c.status, SpeechStatus.paused);
    engine.finish(); // cancelled: nothing happens
    expect(c.group, 0);
    c.resume();
    expect(engine.spoken, ['a1', 'a1']);
    c.skip(1);
    expect(engine.spoken.last, 'b1');
    c.skip(-1);
    expect(engine.spoken.last, 'a1');
    c.setRate(1.5);
    expect(engine.lastRate, 1.5);
    expect(engine.spoken.last, 'a1');
    c.play(const [SpeechItem(0, 'x'), SpeechItem(3, 'y')], startGroup: 2);
    expect(engine.spoken.last, 'y');
    c.stop();
    expect(c.status, SpeechStatus.idle);
    expect(c.group, isNull);
  });
}
