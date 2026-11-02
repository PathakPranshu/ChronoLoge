import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_lock_providers.dart';
import 'pin_widgets.dart';

/// Unlocks the signed-in user's diary with their PIN or device biometrics.
class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({
    required this.userId,
    required this.onUnlocked,
    required this.onSignOut,
    this.displayName,
    super.key,
  });

  final String userId;
  final String? displayName;
  final VoidCallback onUnlocked;
  final VoidCallback onSignOut;

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  String _input = '';
  bool _checking = false;
  bool _biometricsEnabled = false;
  bool _biometricPromptOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndPromptBiometrics();
  }

  Future<void> _loadAndPromptBiometrics() async {
    final service = ref.read(appLockServiceProvider);
    final enabled =
        await service.isBiometricEnabled(widget.userId) &&
        await service.canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometricsEnabled = enabled);
    if (enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useBiometrics());
    }
  }

  Future<void> _useBiometrics() async {
    if (!_biometricsEnabled || _biometricPromptOpen) return;
    setState(() => _biometricPromptOpen = true);
    final unlocked = await ref
        .read(appLockServiceProvider)
        .authenticate('Unlock ChronoLoge to view your private diary.');
    if (!mounted) return;
    setState(() => _biometricPromptOpen = false);
    if (unlocked) widget.onUnlocked();
  }

  void _addDigit(int digit) {
    if (_checking || _input.length == 4) return;
    setState(() {
      _input += digit.toString();
      _error = null;
    });
    if (_input.length == 4) _verifyPin();
  }

  void _removeDigit() {
    if (_checking || _input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = null;
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _checking = true);
    final matches = await ref
        .read(appLockServiceProvider)
        .verifyPin(widget.userId, _input);
    if (!mounted) return;
    if (matches) {
      widget.onUnlocked();
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _checking = false;
      _error = 'Incorrect PIN';
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _input = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = widget.displayName?.trim().split(' ').first;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 58,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    firstName == null || firstName.isEmpty
                        ? 'Unlock ChronoLoge'
                        : 'Welcome back, $firstName',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your four-digit PIN',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 30),
                  PinDots(filled: _input.length, hasError: _error != null),
                  SizedBox(
                    height: 48,
                    child: Center(
                      child: _checking
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _error ?? '',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                    ),
                  ),
                  PinPad(
                    onDigit: _addDigit,
                    onBackspace: _removeDigit,
                    onBiometric: _biometricsEnabled ? _useBiometrics : null,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Sign out and reset app lock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
