/// Native-only AdMob implementation: a stub until native builds are approved.
/// Not imported by the web build. Real ad unit IDs must come from
/// `--dart-define`, never from source.
library;

import 'package:material_ui/material_ui.dart';

import '../ads_service.dart';

class AdMobAdsService implements AdsService {
  const AdMobAdsService();

  @override
  bool get enabled => false;

  @override
  Future<void> init() => throw UnimplementedError('AdMob: native builds only');

  @override
  Widget banner(AdPlacement placement) => const SizedBox.shrink();

  @override
  Future<void> maybeShowInterstitial(
    BuildContext context,
    AdPlacement placement,
  ) async {}
}
