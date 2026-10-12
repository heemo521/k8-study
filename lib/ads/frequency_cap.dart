/// Interstitial frequency cap shared by quiz and practice completions
/// (spec §9.3): at most one per [completionsPerAd] completions and at most one
/// per [minInterval].
library;

const completionsPerAd = 3;
const minInterval = Duration(minutes: 10);

class AdCapState {
  const AdCapState({required this.completionsSinceAd, this.lastShownAt});

  static const initial = AdCapState(completionsSinceAd: 0);

  final int completionsSinceAd;
  final DateTime? lastShownAt;

  Map<String, dynamic> toJson() => {
    'quizzesSinceInterstitial': completionsSinceAd,
    if (lastShownAt != null)
      'lastInterstitialAt': lastShownAt!.toIso8601String(),
  };

  static AdCapState fromJson(Map<String, dynamic> j) => AdCapState(
    completionsSinceAd: j['quizzesSinceInterstitial'] as int,
    lastShownAt: j['lastInterstitialAt'] == null
        ? null
        : DateTime.parse(j['lastInterstitialAt'] as String),
  );
}

abstract interface class AdCapStore {
  AdCapState get adCapState;
  set adCapState(AdCapState value);
}

/// Records one completion and returns whether an interstitial may show now.
/// When it returns true the counter resets and the show time is recorded.
bool registerCompletionAndCheck(AdCapStore store, DateTime now) {
  final s = store.adCapState;
  final count = s.completionsSinceAd + 1;
  final last = s.lastShownAt;
  final allowed =
      count >= completionsPerAd &&
      (last == null || now.difference(last) >= minInterval);
  store.adCapState = allowed
      ? AdCapState(completionsSinceAd: 0, lastShownAt: now)
      : AdCapState(completionsSinceAd: count, lastShownAt: last);
  return allowed;
}
