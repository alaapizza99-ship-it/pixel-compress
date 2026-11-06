import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n.dart';
import '../services/connectivity_service.dart';
import '../services/premium_service.dart';

/// Shows [child] only when the device is online, or the user is a subscriber.
class OnlineGate extends StatefulWidget {
  final Widget child;
  const OnlineGate({super.key, required this.child});

  @override
  State<OnlineGate> createState() => _OnlineGateState();
}

class _OnlineGateState extends State<OnlineGate> {
  bool? _online; // null = still checking
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    PremiumService.isPremium.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _check() async {
    final ok = await ConnectivityService.hasInternet();
    if (mounted && _online != ok) setState(() => _online = ok);
  }

  Future<void> _retry() async {
    setState(() => _online = null);
    await _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    PremiumService.isPremium.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PremiumService.isPremium.value || _online == true) return widget.child;
    if (_online == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .15),
                    shape: BoxShape.circle),
                child: Icon(Icons.wifi_off_rounded, size: 54, color: cs.primary),
              ),
              const SizedBox(height: 28),
              Text(context.tr('offline_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(context.tr('offline_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      height: 1.4, color: cs.onSurface.withValues(alpha: .7))),
              const SizedBox(height: 28),
              FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('retry'))),
            ],
          ),
        ),
      ),
    );
  }
}
