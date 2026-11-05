import 'package:flutter/material.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/banner_ad_widget.dart';
import 'settings_screen.dart';
import 'tool_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PixelCompress',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: cs.primary)),
                        const SizedBox(height: 2),
                        Text(context.tr('tagline'),
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: .6))),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('toggle_theme'),
                    icon: Icon(isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded),
                    onPressed: toggleTheme,
                  ),
                  IconButton(
                    tooltip: context.tr('settings'),
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final t in Tool.values) _ToolCard(tool: t),
                ],
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final Tool tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ToolScreen(tool: tool))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(tool.icon, color: cs.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr(tool.titleKey),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(context.tr(tool.subtitleKey),
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: .6),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Icon(
                    rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: .5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
