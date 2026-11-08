import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../l10n.dart';
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
          .showSnackBar(SnackBar(content: Text(context.tr('link_fail'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, mode, __) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_rounded),
              title: Text(context.tr('dark_theme')),
              value: mode == ThemeMode.dark,
              onChanged: (_) => toggleTheme(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: Text(context.tr('share_app')),
            onTap: () => Share.share(kStoreUrl.isEmpty
                ? context.tr('share_text_nolink')
                : context.tr('share_text', {'url': kStoreUrl})),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_rounded),
            title: Text(context.tr('privacy')),
            onTap: () {
              if (kPrivacyPolicyUrl.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('coming_soon'))));
              } else {
                _open(context, [kPrivacyPolicyUrl]);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(context.tr('about')),
            subtitle: Text(context.tr('version', {'v': kAppVersion})),
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
