import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has the paid plan (no ads, works offline).
/// The purchase flow itself is added later; this only stores the result.
class PremiumService {
  static final ValueNotifier<bool> isPremium = ValueNotifier(false);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      isPremium.value = p.getBool('premium') ?? false;
    } catch (_) {}
  }

  static Future<void> set(bool value) async {
    isPremium.value = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('premium', value);
    } catch (_) {}
  }
}
