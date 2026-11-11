// ============================================================
//  AD CONFIGURATION  -  the ONLY file you edit for monetization
// ============================================================
// kUseTestAds = false  -> REAL ads with the unit IDs below (earnings).
// kUseTestAds = true   -> Google's TEST ads (safe, no earnings).
// Never click your own live ads - AdMob can ban the account. Add your own
// phone as a "Test device" in the AdMob console so it only sees test ads.

// Master switch: set to false to turn ALL ads off (the unlock screens then
// open the locked features for free).
const bool kAdsEnabled = true;

const bool kUseTestAds = false;

// AdMob App ID (from your AdMob account).
const String kAdmobAppId = 'ca-app-pub-3442559127752747~9947195595';

// Your real ad unit IDs.
const String kBannerUnitId = 'ca-app-pub-3442559127752747/3792850788';
const String kInterstitialUnitId = 'ca-app-pub-3442559127752747/9351941400';
const String kRewardedUnitId = 'ca-app-pub-3442559127752747/2487150154';

// Interstitial frequency caps (keeps users happy, protects ratings).
const int kShowInterstitialEveryNTasks = 2;
const int kMinSecondsBetweenInterstitials = 60;

// Rewarded unlock: more than kFreeBatchLimit photos at once, or the
// "Target size" mode, needs one rewarded ad. It then stays unlocked
// for kUnlockMinutes.
const int kFreeBatchLimit = 5;
const int kUnlockMinutes = 30;

// If no rewarded ad can be loaded (e.g. no fill on a new account), unlock anyway
// so users are never stuck. Set to false to require a watched ad.
const bool kUnlockIfAdUnavailable = true;
