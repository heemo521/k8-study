import 'package:material_ui/material_ui.dart';

import '../ads_service.dart';

/// Used when `ADS_ENABLED` is false: renders nothing, shows nothing.
class NoopAdsService implements AdsService {
  const NoopAdsService();

  @override
  bool get enabled => false;

  @override
  Future<void> init() async {}

  @override
  Widget banner(AdPlacement placement) => const SizedBox.shrink();

  @override
  Future<void> maybeShowInterstitial(
    BuildContext context,
    AdPlacement placement,
  ) async {}
}
