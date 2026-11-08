import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';
import 'premium_service.dart';

enum RewardResult { earned, dismissed, unavailable }

class AdService {
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInter = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static String get bannerId => kUseTestAds ? _testBanner : kBannerUnitId;
  static String get _interId => kUseTestAds ? _testInter : kInterstitialUnitId;
  static String get _rewardedId => kUseTestAds ? _testRewarded : kRewardedUnitId;

  /// Ads are shown only when enabled and the user is not a paying subscriber.
  static bool get shouldShowAds => kAdsEnabled && !PremiumService.isPremium.value;

  /// true once the Mobile Ads SDK has been initialised successfully.
  static final ValueNotifier<bool> sdkReady = ValueNotifier(false);

  static InterstitialAd? _ad;
  static bool _loading = false;
  static int _tasks = 0;
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Called after the first frame. Never throws: a problem with ads must not
  /// stop the app.
  static Future<void> init() async {
    if (!kAdsEnabled) return;
    try {
      await _gatherConsent().timeout(const Duration(seconds: 12), onTimeout: () {});
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      sdkReady.value = true;
      _load();
    } catch (_) {}
  }

  /// EU/UK consent form (shown only where required, once it is set up in AdMob).
  static Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
          if (!done.isCompleted) done.complete();
        });
      },
      (FormError e) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  static void _load() {
    if (!shouldShowAds || !sdkReady.value || _loading || _ad != null) return;
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

  /// Call after a task finishes. Shows an interstitial only when the frequency
  /// caps allow; the future completes when the ad is closed (or at once if none).
  static Future<void> maybeShowInterstitial() async {
    if (!shouldShowAds) return;
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

  /// Loads and shows a rewarded ad. The user has already chosen to watch it.
  static Future<RewardResult> showRewarded() async {
    if (!kAdsEnabled || !sdkReady.value) return RewardResult.unavailable;
    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!loaded.isCompleted) loaded.complete(ad);
        },
        onAdFailedToLoad: (_) {
          if (!loaded.isCompleted) loaded.complete(null);
        },
      ),
    );
    final ad = await loaded.future
        .timeout(const Duration(seconds: 15), onTimeout: () => null);
    if (ad == null) return RewardResult.unavailable;

    final done = Completer<RewardResult>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _last = DateTime.now(); // no interstitial right after a rewarded ad
        if (!done.isCompleted) {
          done.complete(earned ? RewardResult.earned : RewardResult.dismissed);
        }
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!done.isCompleted) done.complete(RewardResult.unavailable);
      },
    );
    ad.show(onUserEarnedReward: (_, __) {
      earned = true;
    });
    return done.future;
  }
}
