import '../ads_service.dart';
import '../frequency_cap.dart';
import 'placeholder_ads_service.dart';

AdsService createPlatformAds(AdCapStore capStore) =>
    PlaceholderAdsService(capStore: capStore);
