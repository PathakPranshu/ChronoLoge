import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_lock_providers.dart';
import 'pin_setup_page.dart';
import 'unlock_page.dart';

/// Places PIN and biometric security between Firebase login and the diary UI.
class AppSecurityGate extends ConsumerStatefulWidget {
  const AppSecurityGate({
    required this.userId,
    required this.child,
    required this.onSignOut,
    this.displayName,
    super.key,
  });

  final String userId;
  final String? displayName;
  final Widget child;
  final VoidCallback onSignOut;

  @override
  ConsumerState<AppSecurityGate> createState() => _AppSecurityGateState();
}

class _AppSecurityGateState extends ConsumerState<AppSecurityGate> {
  late Future<bool> _hasPin = _loadPin();

  Future<bool> _loadPin() {
    return ref.read(appLockServiceProvider).hasPin(widget.userId);
  }

  void _finishPinSetup() {
    // Unlocking rebuilds this gate, so setState is unnecessary here.
    _hasPin = Future<bool>.value(true);
    ref.read(appLockSessionProvider.notifier).unlock();
  }

  @override
  void didUpdateWidget(covariant AppSecurityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId) return;
    ref.read(appLockSessionProvider.notifier).lock();
    _hasPin = _loadPin();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(appLockSessionProvider)) return widget.child;

    return FutureBuilder<bool>(
      future: _hasPin,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_reset_rounded, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'The app lock could not be opened on this device.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => setState(() => _hasPin = _loadPin()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                      TextButton(
                        onPressed: widget.onSignOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }

        if (!snapshot.requireData) {
          return PinSetupPage(
            userId: widget.userId,
            onSignOut: widget.onSignOut,
            onComplete: _finishPinSetup,
          );
        }

        return UnlockPage(
          userId: widget.userId,
          displayName: widget.displayName,
          onSignOut: widget.onSignOut,
          onUnlocked: ref.read(appLockSessionProvider.notifier).unlock,
        );
      },
    );
  }
}
