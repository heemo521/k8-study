# Publishing to Google Play (and the App Store)

The same Flutter code builds the website, an Android app and an iOS app. The
website never shows ads. The Android and iOS apps show Google AdMob ads in the
spots listed in spec §9.3: a banner at the end of the topic list, the practice
hub and the notes (between sections 2 and 3), and at most one full-screen ad
per 3 finished quizzes or practice runs, never more than once per 10 minutes.
Never during a quiz or flashcards.

Until real IDs are filled in, the apps show Google's **test ads**. They look
like real ads with a "Test Ad" label and earn nothing.

## One-time setup (owner only)

1. **Google Play developer account** at <https://play.google.com/console>.
   One-time fee of US$25, plus ID verification. New personal accounts must run
   a closed test with at least 12 testers for 14 days before going public.
2. **AdMob account** at <https://admob.google.com>. Add an Android app
   (and an iOS app if you publish there). AdMob gives you:
   - an **app ID** like `ca-app-pub-1234567890123456~1234567890`
   - one **banner** ad unit ID and one **interstitial** ad unit ID, like
     `ca-app-pub-1234567890123456/1234567890`
   - Set up the EEA/UK consent message under *Privacy & messaging*
     (pick "Use the default message"). The app already shows it when needed.
3. **Upload key** (signs the app; keep it safe and backed up):

   ```sh
   keytool -genkey -v -keystore ~/k8study-upload.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```

   Then create `android/key.properties` (git-ignored, never commit it):

   ```properties
   storeFile=/full/path/to/k8study-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   admobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
   ```

## Build the Android app bundle

```sh
flutter build appbundle --release \
  --dart-define=ADS_ENABLED=true \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXXXXXXXXXXXXXX/1111111111 \
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXXXXXXXXXXXXXX/2222222222
```

Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console.
Bump `version:` in `pubspec.yaml` (the number after `+` must go up) for every
upload.

## Play Console forms

- **Privacy policy URL:** <https://heemo521.github.io/k8-study/privacy.html>
  (served from `web/privacy.html` once merged).
- **Ads:** Yes, the app contains ads.
- **Data safety:** no data collected by the app itself; the AdMob SDK collects
  device or other IDs, approximate location and app interactions, for
  advertising and analytics, encrypted in transit, not optional.
- **Content rating:** reference / education questionnaire, no violence etc.
- **Target audience:** 18+ (avoids the extra rules for children's apps).
- **Store listing:** short and full description, 512×512 icon, 1024×500
  feature graphic, at least 2 phone screenshots.
- **App ID** `io.github.heemo521.k8study` is permanent once uploaded.

## iOS (optional, needs a Mac)

Apple Developer Program (US$99 a year) and Xcode are required. Put the real
AdMob iOS app ID in `ios/Flutter/AdMob.local.xcconfig` (git-ignored):

```
ADMOB_APP_ID = ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
```

Build with the same `--dart-define` flags (`flutter build ipa ...`) using the
iOS ad unit IDs, and upload with Xcode or Transporter.
