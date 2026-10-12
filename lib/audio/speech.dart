import 'package:flutter/foundation.dart';

import 'speech_engine_stub.dart'
    if (dart.library.js_interop) 'speech_engine_web.dart';

/// Platform text-to-speech. The web build uses the browser's speech engine
/// with an on-device voice when one exists, so reading works offline.
abstract class SpeechEngine {
  /// Creates the engine for this platform.
  factory SpeechEngine.platform() => createPlatformSpeechEngine();

  bool get supported;

  /// Speaks [text]; calls [onDone] with true when it finished, false when
  /// it could not be spoken (e.g. no voice). One utterance at a time.
  void speak(
    String text, {
    required double rate,
    required void Function(bool ok) onDone,
  });

  /// Stops speaking immediately; the pending [onDone] is not called.
  void cancel();
}

/// One spoken chunk, tagged with the section ([group]) it belongs to.
class SpeechItem {
  const SpeechItem(this.group, this.text);

  final int group;
  final String text;
}

enum SpeechStatus { idle, playing, paused }

/// Reads a queue of [SpeechItem]s aloud, one at a time. Pausing cancels the
/// current chunk and resuming restarts it, which behaves the same on every
/// browser (native pause/resume is unreliable on mobile).
class SpeechController extends ChangeNotifier {
  SpeechController(this.engine);

  final SpeechEngine engine;

  static const rates = [0.75, 1.0, 1.25, 1.5, 2.0];

  List<SpeechItem> _queue = const [];
  int _pos = 0;
  int _token = 0;
  SpeechStatus _status = SpeechStatus.idle;
  double _rate = 1.0;

  /// Called when every chunk of a group has been spoken.
  void Function(int group)? onGroupDone;

  /// Set when speaking failed and playback stopped; cleared on [play].
  String? error;

  static const noVoiceMessage =
      "Read-aloud isn't available. Your device may need a text-to-speech "
      'voice installed (an on-device voice also works offline).';

  bool get supported => engine.supported;
  SpeechStatus get status => _status;
  double get rate => _rate;

  /// Group (section) being read, or null when idle.
  int? get group => _status == SpeechStatus.idle ? null : _queue[_pos].group;

  void play(List<SpeechItem> items, {int startGroup = 0}) {
    final start = items.indexWhere((i) => i.group >= startGroup);
    if (items.isEmpty || start < 0) return;
    engine.cancel();
    error = null;
    _queue = items;
    _pos = start;
    _status = SpeechStatus.playing;
    _speakCurrent();
    notifyListeners();
  }

  void pause() {
    if (_status != SpeechStatus.playing) return;
    _token++;
    engine.cancel();
    _status = SpeechStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (_status != SpeechStatus.paused) return;
    _status = SpeechStatus.playing;
    _speakCurrent();
    notifyListeners();
  }

  void stop() {
    if (_status == SpeechStatus.idle) return;
    _token++;
    engine.cancel();
    _status = SpeechStatus.idle;
    notifyListeners();
  }

  /// Jumps to the start of the next (+1) or previous (-1) group.
  void skip(int delta) {
    if (_status == SpeechStatus.idle) return;
    final current = _queue[_pos].group;
    final target = current + delta;
    final i = _queue.indexWhere((item) => item.group == target);
    if (i < 0) {
      if (delta > 0) stop();
      return;
    }
    _pos = i;
    if (_status == SpeechStatus.playing) {
      engine.cancel();
      _speakCurrent();
    }
    notifyListeners();
  }

  void setRate(double rate) {
    _rate = rate;
    if (_status == SpeechStatus.playing) {
      engine.cancel();
      _speakCurrent();
    }
    notifyListeners();
  }

  void _speakCurrent() {
    final token = ++_token;
    engine.speak(
      _queue[_pos].text,
      rate: _rate,
      onDone: (ok) {
        if (token != _token) return;
        if (ok) {
          _advance();
        } else {
          _token++;
          error = noVoiceMessage;
          _status = SpeechStatus.idle;
          notifyListeners();
        }
      },
    );
  }

  void _advance() {
    final finished = _queue[_pos].group;
    _pos++;
    final groupEnded = _pos >= _queue.length || _queue[_pos].group != finished;
    if (groupEnded) onGroupDone?.call(finished);
    if (_pos >= _queue.length) {
      _pos = _queue.length - 1;
      _status = SpeechStatus.idle;
    } else {
      _speakCurrent();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _token++;
    engine.cancel();
    super.dispose();
  }
}

/// Engine for platforms without speech; [supported] is false.
class UnsupportedSpeechEngine implements SpeechEngine {
  const UnsupportedSpeechEngine();

  @override
  bool get supported => false;

  @override
  void speak(
    String text, {
    required double rate,
    required void Function(bool ok) onDone,
  }) => onDone(false);

  @override
  void cancel() {}
}
