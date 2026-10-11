import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../engine/clock.dart';
import '../ads_service.dart';
import '../frequency_cap.dart';

const bannerSize = Size(320, 50);
const interstitialCloseDelay = Duration(seconds: 3);

/// Web v1 implementation: AdSense-sized placeholders, no ad network calls and
/// no `adsbygoogle.js`. Real AdSense is a later, separately approved change.
class PlaceholderAdsService implements AdsService {
  PlaceholderAdsService({required this.capStore, this.clock = const SystemClock()});

  final AdCapStore capStore;
  final Clock clock;

  @override
  bool get enabled => true;

  @override
  Future<void> init() async {}

  @override
  Widget banner(AdPlacement placement) =>
      _BannerPlaceholder(key: ValueKey('ad-banner-${placement.name}'));

  @override
  Future<void> maybeShowInterstitial(
      BuildContext context, AdPlacement placement) async {
    if (!registerCompletionAndCheck(capStore, clock.now())) return;
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Advertisement',
      pageBuilder: (_, _, _) => const _InterstitialPlaceholder(),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Semantics(
          label: 'Ad placeholder',
          child: Container(
            width: bannerSize.width,
            height: bannerSize.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              color: scheme.surfaceContainerHighest,
            ),
            child: Text('Ad placeholder',
                style: Theme.of(context).textTheme.labelMedium),
          ),
        ),
      ),
    );
  }
}

class _InterstitialPlaceholder extends StatefulWidget {
  const _InterstitialPlaceholder();

  @override
  State<_InterstitialPlaceholder> createState() =>
      _InterstitialPlaceholderState();
}

class _InterstitialPlaceholderState extends State<_InterstitialPlaceholder> {
  bool _canClose = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(interstitialCloseDelay, () {
      if (mounted) setState(() => _canClose = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const ValueKey('ad-interstitial'),
      backgroundColor: scheme.surfaceContainerHighest,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Text('Ad placeholder',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: FilledButton.tonal(
                onPressed: _canClose ? () => Navigator.of(context).pop() : null,
                child: Text(_canClose ? 'Close' : 'Close in 3s'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
