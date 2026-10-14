import '../ads_service.dart';
import '../frequency_cap.dart';
import 'admob_ads_service.dart';

AdsService createPlatformAds(AdCapStore capStore) =>
    AdMobAdsService(capStore: capStore);
