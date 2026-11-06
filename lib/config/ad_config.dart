// ============================================================
//  AD CONFIGURATION  -  the ONLY file you edit for monetization
// ============================================================
// 1) Keep kUseTestAds = true while developing/testing (safe, no policy risk).
// 2) When ready to earn, create your AdMob app + 2 ad units, paste the IDs
//    below, then set kUseTestAds = false and push to GitHub.
// Never click your own live ads - AdMob can ban the account.

// Master switch: set to false to turn ALL ads off (e.g. if ads ever cause a problem).
const bool kAdsEnabled = true;

const bool kUseTestAds = true;

// AdMob *App* ID (format: ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY).
// Default below is Google's official TEST app id.
const String kAdmobAppId = 'ca-app-pub-3940256099942544~3347511713';

// Your real ad unit IDs (format: ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY).
const String kBannerUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
const String kInterstitialUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

// Interstitial frequency caps (keeps users happy, protects ratings).
const int kShowInterstitialEveryNTasks = 2;
const int kMinSecondsBetweenInterstitials = 60;
