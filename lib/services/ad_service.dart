// Temporary no-ads version used to isolate a launch crash.
class AdService {
  static String get bannerId => '';
  static Future<void> init() async {}
  static Future<void> maybeShowInterstitial() async {}
}
