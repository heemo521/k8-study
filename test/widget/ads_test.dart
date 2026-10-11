// Spec §9: placements, flag behaviour and the interstitial cap.
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/ads/frequency_cap.dart';
import 'package:k8_study/ads/impl/placeholder_ads_service.dart';
import 'package:k8_study/progress/progress_store.dart';
import 'package:k8_study/widgets/question_view.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

final adKey = find.byWidgetPredicate(
    (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('ad-'));

Future<void> scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('flag off: no ad slots anywhere', (tester) async {
    await setPhoneViewport(tester);
    for (final path in ['/', '/topic/kubeadm/notes', '/practice']) {
      await pumpApp(tester, initialLocation: path);
      await scrollToEnd(tester);
      expect(adKey, findsNothing, reason: path);
    }
  });

  testWidgets('flag on: banners only at the spec placements', (tester) async {
    await setPhoneViewport(tester);
    PlaceholderAdsService ads(ProgressStore p) =>
        PlaceholderAdsService(capStore: p, clock: FixedClock(testNow));

    final expected = {
      '/': 'ad-banner-topicListBanner',
      '/topic/kubeadm/notes': 'ad-banner-studyNotesBanner',
      '/practice': 'ad-banner-practiceHubBanner',
    };
    for (final e in expected.entries) {
      await pumpApp(tester, ads: ads, initialLocation: e.key);
      await scrollToEnd(tester);
      expect(find.byKey(ValueKey(e.value)), findsOneWidget, reason: e.key);
      expect(adKey, findsOneWidget, reason: '${e.key}: exactly one ad');
    }
    for (final path in [
      '/topic/kubeadm',
      '/topic/kubeadm/cards',
      '/topic/kubeadm/quiz',
      '/practice/mixed/run',
      '/progress',
      '/about',
    ]) {
      await pumpApp(tester, ads: ads, initialLocation: path);
      await scrollToEnd(tester);
      expect(adKey, findsNothing, reason: path);
    }
  });

  testWidgets('interstitial shows on the 3rd completion, before results',
      (tester) async {
    await setPhoneViewport(tester);
    final h = await pumpApp(
      tester,
      ads: (p) => PlaceholderAdsService(capStore: p, clock: FixedClock(testNow)),
      initialLocation: '/topic/namespaces/quiz',
    );
    // Two completions already recorded.
    h.progress.adCapState = const AdCapState(completionsSinceAd: 2);

    for (var i = 0; i < 10; i++) {
      final view = tester.widget<QuestionView>(find.byType(QuestionView));
      final o = view.presented.question.options.firstWhere((o) => o.correct);
      final f = find.descendant(
          of: find.byType(QuestionView), matching: find.text(o.text)).first;
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next')));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('ad-interstitial')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-score')), findsNothing);

    await tester.pump(interstitialCloseDelay);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz-score')), findsOneWidget);
    expect(h.progress.adCapState.completionsSinceAd, 0);
  });
}
