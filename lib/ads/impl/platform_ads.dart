/// Picks the ads implementation for the platform being compiled: AdSense-sized
/// placeholders on the web, AdMob on Android/iOS. The conditional export keeps
/// the AdMob SDK out of the web build.
library;

export 'platform_ads_web.dart'
    if (dart.library.io) 'platform_ads_native.dart';
