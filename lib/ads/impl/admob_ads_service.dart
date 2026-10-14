/// Native (Android/iOS) AdMob implementation. Never compiled into the web
/// build: `platform_ads.dart` only exports it where `dart:io` exists.
///
/// Ad unit IDs come from `--dart-define` (spec §9.2). Without them Google's
/// public test units are used, which show labelled test ads and earn nothing.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import '../../engine/clock.dart';
import '../ads_service.dart';
import '../frequency_cap.dart';

const _bannerDefine = String.fromEnvironment('ADMOB_BANNER_ID');
const _interstitialDefine = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');

// Google's documented test ad units.
const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

String get _bannerUnitId => _bannerDefine.isNotEmpty
    ? _bannerDefine
    : (Platform.isIOS ? _testBannerIos : _testBannerAndroid);

String get _interstitialUnitId => _interstitialDefine.isNotEmpty
    ? _interstitialDefine
    : (Platform.isIOS ? _testInterstitialIos : _testInterstitialAndroid);

class AdMobAdsService implements AdsService {
  AdMobAdsService({required this.capStore, this.clock = const SystemClock()});

  final AdCapStore capStore;
  final Clock clock;

  bool _canRequestAds = false;
  InterstitialAd? _interstitial;

  @override
  bool get enabled => _canRequestAds;

  /// Asks for consent where the law requires it (EEA/UK), then starts the SDK.
  /// Any failure leaves ads off; the app works the same without them.
  @override
  Future<void> init() async {
    try {
      await _gatherConsent();
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (!_canRequestAds) return;
      await MobileAds.instance.initialize();
      _loadInterstitial();
    } catch (_) {
      _canRequestAds = false;
    }
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!done.isCompleted) done.complete();
      }),
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  @override
  Widget banner(AdPlacement placement) => enabled
      ? _AdMobBanner(key: ValueKey('ad-banner-${placement.name}'))
      : const SizedBox.shrink();

  @override
  Future<void> maybeShowInterstitial(
    BuildContext context,
    AdPlacement placement,
  ) async {
    final ad = _interstitial;
    if (!enabled || ad == null) return;
    if (!registerCompletionAndCheck(capStore, clock.now())) return;
    _interstitial = null;
    final closed = Completer<void>();
    void finish(InterstitialAd ad) {
      ad.dispose();
      _loadInterstitial();
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (ad, _) => finish(ad),
    );
    await ad.show();
    await closed.future;
  }
}

/// A standard 320×50 banner. The slot keeps its height while loading so the
/// page does not jump (spec §9.3), and collapses if no ad can be loaded.
class _AdMobBanner extends StatefulWidget {
  const _AdMobBanner({super.key});

  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  static const _size = AdSize.banner;

  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      size: _size,
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    if (!_failed) _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: _size.width.toDouble(),
          height: _size.height.toDouble(),
          child: _loaded ? AdWidget(ad: _ad!) : null,
        ),
      ),
    );
  }
}
