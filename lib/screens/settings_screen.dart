import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _open(BuildContext context, List<String> urls) async {
    for (final u in urls) {
      try {
        if (await launchUrl(Uri.parse(u),
            mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open the link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, mode, __) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_rounded),
              title: const Text('Dark theme'),
              value: mode == ThemeMode.dark,
              onChanged: (_) => toggleTheme(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_rate_rounded),
            title: const Text('Rate the app'),
            onTap: () => _open(context,
                ['market://details?id=$kPackageName', kStoreUrl]),
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('Share the app'),
            onTap: () => Share.share(
                'Compress, resize and convert photos with PixelCompress: $kStoreUrl'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_rounded),
            title: const Text('Privacy policy'),
            onTap: () {
              if (kPrivacyPolicyUrl.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')));
              } else {
                _open(context, [kPrivacyPolicyUrl]);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About'),
            subtitle: const Text('Version $kAppVersion'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'PixelCompress',
              applicationVersion: kAppVersion,
              applicationLegalese: '© 2026 PixelCompress',
            ),
          ),
        ],
      ),
    );
  }
}
