import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/premium_service.dart';
import 'theme.dart';

/// Any startup/runtime error is shown as a red bar so it can be reported.
final ValueNotifier<String?> lastError = ValueNotifier(null);

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) => lastError.value = d.exceptionAsString();
    try {
      await loadTheme();
      await PremiumService.load();
    } catch (_) {}
    runApp(const PixelCompressApp());

    // Start ads only after the first frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.init().catchError((e) {
        lastError.value = 'Ads: $e';
      });
    });
  }, (error, stack) {
    lastError.value = error.toString();
  });
}

class PixelCompressApp extends StatelessWidget {
  const PixelCompressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
          title: 'PixelCompress',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => ValueListenableBuilder<String?>(
            valueListenable: lastError,
            builder: (_, err, __) => Column(
              children: [
                if (err != null)
                  Material(
                    color: Colors.red,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(err,
                            maxLines: 6,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ),
                Expanded(child: child!),
              ],
            ),
          ),
          home: const SplashScreen(),
        ),
    );
  }
}
