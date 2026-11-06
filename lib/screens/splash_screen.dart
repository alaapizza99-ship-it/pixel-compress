import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'online_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    var done = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      done = prefs.getBool('onboarded') ?? false;
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) =>
            done
            ? const OnlineGate(child: HomeScreen())
            : const OnboardingScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141A),
      body: Center(
        child: FadeTransition(
          opacity: _c,
          child: ScaleTransition(
            scale: Tween(begin: .8, end: 1.0)
                .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset('assets/icon/icon.png',
                      width: 120, height: 120),
                ),
                const SizedBox(height: 20),
                const Text('PixelCompress',
                    style: TextStyle(
                        color: Color(0xFF00E08A),
                        fontSize: 28,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(context.tr('tagline'),
                    style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
