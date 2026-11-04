import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> loadTheme() async {
  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value =
      prefs.getBool('dark') == false ? ThemeMode.light : ThemeMode.dark;
}

Future<void> toggleTheme() async {
  final dark = themeNotifier.value != ThemeMode.dark;
  themeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('dark', dark);
}

const _neon = Color(0xFF00E08A);
const _teal = Color(0xFF00A67E);

FilledButtonThemeData _btn(Color bg, Color fg) => FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF12141A),
        colorScheme: const ColorScheme.dark(
          primary: _neon,
          onPrimary: Colors.black,
          surface: Color(0xFF1C1F26),
          secondary: _neon,
        ),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF12141A), elevation: 0),
        filledButtonTheme: _btn(_neon, Colors.black),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        colorScheme: const ColorScheme.light(
          primary: _teal,
          onPrimary: Colors.white,
          surface: Colors.white,
          secondary: _teal,
        ),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF4F7F6), elevation: 0),
        filledButtonTheme: _btn(_teal, Colors.white),
      );
}
