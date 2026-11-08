import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ad_config.dart';
import '../l10n.dart';
import 'ad_service.dart';
import 'premium_service.dart';

/// Locked features (batches over kFreeBatchLimit photos, "Target size") open for
/// kUnlockMinutes after the user chooses to watch one rewarded ad. Subscribers
/// are always unlocked.
class UnlockService {
  static DateTime? _until;

  static bool get isUnlocked =>
      PremiumService.isPremium.value ||
      (_until != null && _until!.isAfter(DateTime.now()));

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ms = p.getInt('unlock_until');
      if (ms != null) _until = DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}
  }

  static Future<void> _unlock() async {
    _until = DateTime.now().add(const Duration(minutes: kUnlockMinutes));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('unlock_until', _until!.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Asks the user, shows the rewarded ad if they agree. true = unlocked.
  static Future<bool> request(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    final doneMsg = context.tr('unlock_done', {'min': kUnlockMinutes});
    final incompleteMsg = context.tr('unlock_incomplete');
    final unavailableMsg = context.tr('unlock_unavailable');
    final laterMsg = context.tr('unlock_try_later');

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('unlock_title')),
        content: Text(ctx.tr(
            'unlock_body', {'limit': kFreeBatchLimit, 'min': kUnlockMinutes})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('unlock_cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('unlock_watch'))),
        ],
      ),
    );
    if (go != true) return false;

    showDialog(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
          canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    final result = await AdService.showRewarded();
    nav.pop(); // close the loading indicator

    switch (result) {
      case RewardResult.earned:
        await _unlock();
        messenger.showSnackBar(SnackBar(content: Text(doneMsg)));
        return true;
      case RewardResult.unavailable:
        if (kUnlockIfAdUnavailable) {
          await _unlock();
          messenger.showSnackBar(SnackBar(content: Text(unavailableMsg)));
          return true;
        }
        messenger.showSnackBar(SnackBar(content: Text(laterMsg)));
        return false;
      case RewardResult.dismissed:
        messenger.showSnackBar(SnackBar(content: Text(incompleteMsg)));
        return false;
    }
  }
}
