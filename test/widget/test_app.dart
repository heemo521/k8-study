import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/ads/ads_service.dart';
import 'package:k8_study/ads/impl/noop_ads_service.dart';
import 'package:k8_study/app/app.dart';
import 'package:k8_study/content/content_loader.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/engine/clock.dart';
import 'package:k8_study/progress/progress_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixedClock implements Clock {
  FixedClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}

final testNow = DateTime(2026, 10, 11, 9);

/// Phone viewport from spec §3.1.
Future<void> setPhoneViewport(WidgetTester tester,
    {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class TestHarness {
  TestHarness(this.content, this.progress, this.clock);
  final ContentBundle content;
  final ProgressStore progress;
  final FixedClock clock;
}

ContentBundle? _content;

Future<TestHarness> pumpApp(
  WidgetTester tester, {
  AdsService Function(ProgressStore)? ads,
  Map<String, Object> prefs = const {},
  String initialLocation = '/',
}) async {
  _content ??= await tester.runAsync(() => ContentLoader(rootBundle).load());
  SharedPreferences.setMockInitialValues(prefs);
  final clock = FixedClock(testNow);
  final progress =
      ProgressStore(await SharedPreferences.getInstance(), clock: clock);
  await tester.pumpWidget(K8StudyApp(
    // Fresh state per pump so a new initialLocation takes effect.
    key: UniqueKey(),
    content: _content!,
    progress: progress,
    ads: ads?.call(progress) ?? const NoopAdsService(),
    clock: clock,
    random: Random(42),
    initialLocation: initialLocation,
  ));
  await tester.pumpAndSettle();
  return TestHarness(_content!, progress, clock);
}
