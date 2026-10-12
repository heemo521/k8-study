import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'speech.dart';

SpeechEngine createPlatformSpeechEngine() => _WebSpeechEngine();

/// Web Speech API. Prefers an on-device ("localService") English voice so
/// reading keeps working offline; falls back to the browser default.
class _WebSpeechEngine implements SpeechEngine {
  // Held so the browser doesn't garbage-collect the utterance (and drop its
  // end event) while it is still speaking.
  web.SpeechSynthesisUtterance? _current;

  web.SpeechSynthesis? get _synth {
    try {
      return web.window.speechSynthesis;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get supported => _synth != null;

  web.SpeechSynthesisVoice? _pickVoice() {
    final voices = _synth!.getVoices().toDart;
    final lang = web.window.navigator.language.toLowerCase();
    bool english(web.SpeechSynthesisVoice v) =>
        v.lang.toLowerCase().startsWith('en');
    for (final test in <bool Function(web.SpeechSynthesisVoice)>[
      (v) => v.localService && v.lang.toLowerCase() == lang,
      (v) => v.localService && english(v),
      (v) => v.lang.toLowerCase() == lang,
      english,
    ]) {
      for (final v in voices) {
        if (test(v)) return v;
      }
    }
    return null;
  }

  @override
  void speak(
    String text, {
    required double rate,
    required void Function(bool ok) onDone,
  }) {
    final synth = _synth;
    if (synth == null) {
      onDone(false);
      return;
    }
    if (synth.getVoices().toDart.isEmpty) {
      // Chrome loads voices asynchronously; give it a moment, then fail
      // rather than "speak" silently with no voice.
      _whenVoicesLoaded(synth).then((ok) {
        if (ok) {
          _speak(synth, text, rate, onDone);
        } else {
          onDone(false);
        }
      });
      return;
    }
    _speak(synth, text, rate, onDone);
  }

  Future<bool> _whenVoicesLoaded(web.SpeechSynthesis synth) {
    final done = Completer<bool>();
    void check() {
      if (!done.isCompleted) {
        done.complete(synth.getVoices().toDart.isNotEmpty);
      }
    }

    synth.onvoiceschanged = ((web.Event _) => check()).toJS;
    Timer(const Duration(milliseconds: 1500), check);
    return done.future;
  }

  void _speak(
    web.SpeechSynthesis synth,
    String text,
    double rate,
    void Function(bool ok) onDone,
  ) {
    final u = web.SpeechSynthesisUtterance(text)..rate = rate;
    final voice = _pickVoice();
    if (voice != null) {
      u.voice = voice;
      u.lang = voice.lang;
    }
    var done = false;
    void finish(bool ok) {
      if (done) return;
      done = true;
      if (identical(_current, u)) _current = null;
      onDone(ok);
    }

    u.onend = ((web.Event _) => finish(true)).toJS;
    u.onerror = ((web.Event e) {
      // "interrupted"/"canceled" come from our own cancel(): no callback.
      final error = (e as web.SpeechSynthesisErrorEvent).error;
      if (error == 'interrupted' || error == 'canceled') {
        done = true;
        return;
      }
      finish(false);
    }).toJS;
    _current = u;
    synth.speak(u);
  }

  @override
  void cancel() {
    _current = null;
    _synth?.cancel();
  }
}
