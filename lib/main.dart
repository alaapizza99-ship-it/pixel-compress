import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadTheme();
  AdService.init(); // not awaited: never block app start on ads
  runApp(const PixelCompressApp());
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
        home: const SplashScreen(),
      ),
    );
  }
}
