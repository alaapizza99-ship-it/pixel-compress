import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';

class AdService {
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInter = 'ca-app-pub-3940256099942544/1033173712';

  static String get bannerId => kUseTestAds ? _testBanner : kBannerUnitId;
  static String get _interId => kUseTestAds ? _testInter : kInterstitialUnitId;

  static InterstitialAd? _ad;
  static bool _loading = false;
  static int _tasks = 0;
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> init() async {
    await MobileAds.instance.initialize();
    _load();
  }

  static void _load() {
    if (_loading || _ad != null) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _interId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  /// Call after a task finishes. Shows an interstitial only when frequency
  /// caps allow; the returned future completes when the ad is closed.
  static Future<void> maybeShowInterstitial() async {
    _tasks++;
    final ad = _ad;
    if (ad == null) {
      _load();
      return;
    }
    if (_tasks % kShowInterstitialEveryNTasks != 0) return;
    if (DateTime.now().difference(_last).inSeconds <
        kMinSecondsBetweenInterstitials) return;

    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _ad = null;
        _last = DateTime.now();
        _load();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _ad = null;
        _load();
        if (!done.isCompleted) done.complete();
      },
    );
    ad.show();
    return done.future;
  }
}
