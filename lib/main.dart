import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ads_service.dart';
import 'ads/impl/noop_ads_service.dart';
import 'ads/impl/placeholder_ads_service.dart';
import 'app/app.dart';
import 'content/content_loader.dart';
import 'progress/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalog = await ContentLoader(rootBundle).load();
  final progress = ProgressStore(await SharedPreferences.getInstance());

  // The only place an ads implementation is chosen (spec §9.1).
  final AdsService ads = adsEnabledFlag
      ? PlaceholderAdsService(capStore: progress)
      : const NoopAdsService();
  await ads.init();

  runApp(K8StudyApp(catalog: catalog, progress: progress, ads: ads));
}
