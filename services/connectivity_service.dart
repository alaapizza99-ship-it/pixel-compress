import 'dart:async';
import 'dart:io';

class ConnectivityService {
  /// True only when a real DNS lookup works, so "connected to Wi-Fi without
  /// internet" is correctly treated as offline.
  static Future<bool> hasInternet() async {
    for (final host in const ['google.com', 'cloudflare.com']) {
      try {
        final r = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 4));
        if (r.isNotEmpty && r.first.rawAddress.isNotEmpty) return true;
      } catch (_) {}
    }
    return false;
  }
}
