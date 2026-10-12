import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../audio/speech.dart';
import '../content/models.dart';
import '../engine/clock.dart';
import '../progress/progress_store.dart';
import 'router.dart';
import 'session_store.dart';
import 'theme.dart';

/// Root widget. Dependencies are injected so tests can supply fakes.
class K8StudyApp extends StatefulWidget {
  const K8StudyApp({
    super.key,
    required this.catalog,
    required this.progress,
    required this.ads,
    this.clock = const SystemClock(),
    this.random,
    this.speech,
    this.initialLocation = '/',
  });

  final Catalog catalog;
  final ProgressStore progress;
  final AdsService ads;
  final Clock clock;
  final Random? random;

  /// Text-to-speech engine; defaults to the platform's.
  final SpeechEngine? speech;
  final String initialLocation;

  @override
  State<K8StudyApp> createState() => _K8StudyAppState();
}

class _K8StudyAppState extends State<K8StudyApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );
  final _session = SessionStore();
  late final Random _random = widget.random ?? Random();
  late final SpeechController _speech = SpeechController(
    widget.speech ?? SpeechEngine.platform(),
  );

  @override
  void dispose() {
    _speech.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Catalog>.value(value: widget.catalog),
        ChangeNotifierProvider<ProgressStore>.value(value: widget.progress),
        // The selected subject; screens depend on this, not on the catalog.
        ProxyProvider<ProgressStore, ContentBundle>(
          update: (_, progress, _) =>
              widget.catalog.subject(progress.subjectId),
          updateShouldNotify: (a, b) => !identical(a, b),
        ),
        Provider<AdsService>.value(value: widget.ads),
        Provider<Clock>.value(value: widget.clock),
        Provider<Random>.value(value: _random),
        Provider<SessionStore>.value(value: _session),
        ChangeNotifierProvider<SpeechController>.value(value: _speech),
      ],
      child: MaterialApp.router(
        title: 'K8 Study',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        routerConfig: _router,
      ),
    );
  }
}
