/// The only ads API that screens may use (spec §9.1). Screens never import an
/// ad SDK or anything under `ads/impl/`; a test enforces this.
library;

import 'package:material_ui/material_ui.dart';

enum AdPlacement {
  topicListBanner,
  studyNotesBanner,
  practiceHubBanner,
  quizComplete,
  practiceComplete,
}

/// Compile-time flag: `--dart-define=ADS_ENABLED=true`. Off by default.
const adsEnabledFlag = bool.fromEnvironment('ADS_ENABLED');

abstract interface class AdsService {
  bool get enabled;

  Future<void> init();

  /// A fixed-height slot widget, or an empty box when ads are disabled.
  Widget banner(AdPlacement placement);

  /// Shows an interstitial if enabled and the frequency cap allows.
  /// Completes when it is dismissed (or immediately if none is shown).
  Future<void> maybeShowInterstitial(
    BuildContext context,
    AdPlacement placement,
  );
}
