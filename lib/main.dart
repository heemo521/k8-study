import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ads_service.dart';
import 'ads/impl/noop_ads_service.dart';
import 'ads/impl/platform_ads.dart';
import 'app/app.dart';
import 'content/content_loader.dart';
import 'progress/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalog = await ContentLoader(rootBundle).load();
  final progress = ProgressStore(await SharedPreferences.getInstance());

  // The only place an ads implementation is chosen (spec §9.1).
  final AdsService ads = adsEnabledFlag
      ? createPlatformAds(progress)
      : const NoopAdsService();
  await ads.init();

  // Pushed pages (e.g. a "Study first" topic) update the address bar too.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(K8StudyApp(catalog: catalog, progress: progress, ads: ads));
}
