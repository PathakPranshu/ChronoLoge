import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_lock_providers.dart';
import 'pin_widgets.dart';

/// Creates or replaces the four-digit PIN for one signed-in account.
class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({
    required this.userId,
    required this.onComplete,
    this.canCancel = false,
    this.onSignOut,
    super.key,
  });

  final String userId;
  final VoidCallback onComplete;
  final bool canCancel;
  final VoidCallback? onSignOut;

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  String _firstPin = '';
  String _input = '';
  bool _confirming = false;
  bool _matched = false;
  bool _saving = false;
  bool _biometricsSupported = false;
  bool _biometricsEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final service = ref.read(appLockServiceProvider);
    final results = await Future.wait([
      service.canUseBiometrics(),
      service.isBiometricEnabled(widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      _biometricsSupported = results[0];
      _biometricsEnabled = results[0] && results[1];
    });
  }

  void _addDigit(int digit) {
    if (_saving || _matched || _input.length == 4) return;
    setState(() {
      _error = null;
      _input += digit.toString();
    });
    if (_input.length != 4) return;

    if (!_confirming) {
      final createdPin = _input;
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        setState(() {
          _firstPin = createdPin;
          _input = '';
          _confirming = true;
        });
      });
      return;
    }

    if (_input == _firstPin) {
      setState(() => _matched = true);
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _error = 'The PINs do not match. Try again.');
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _input = '');
    });
  }

  void _removeDigit() {
    if (_saving || _input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _matched = false;
      _error = null;
    });
  }

  Future<void> _setBiometrics(bool enabled) async {
    if (!enabled) {
      setState(() => _biometricsEnabled = false);
      return;
    }
    final verified = await ref
        .read(appLockServiceProvider)
        .authenticate('Confirm your identity to enable biometric unlock.');
    if (!mounted) return;
    setState(() {
      _biometricsEnabled = verified;
      if (!verified) _error = 'Biometric verification was not completed.';
    });
  }

  Future<void> _save() async {
    if (!_matched || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(appLockServiceProvider);
      await service.savePin(widget.userId, _firstPin);
      await service.setBiometricEnabled(widget.userId, _biometricsEnabled);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The app lock could not be saved. Please try again.';
      });
      return;
    }

    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.canCancel,
        title: Text(_confirming ? 'Confirm your PIN' : 'Secure your diary'),
        actions: [
          if (!widget.canCancel && widget.onSignOut != null)
            TextButton(
              onPressed: _saving ? null : widget.onSignOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 52,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _confirming
                        ? 'Enter the same four digits again.'
                        : 'Create a four-digit PIN to protect your memories.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 28),
                  PinDots(filled: _input.length, hasError: _error != null),
                  SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        _error ?? (_matched ? 'PIN confirmed' : ''),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _error == null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                  PinPad(onDigit: _addDigit, onBackspace: _removeDigit),
                  if (_confirming && _biometricsSupported) ...[
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.fingerprint_rounded),
                      title: const Text('Biometric unlock'),
                      subtitle: const Text('Use fingerprint or Face ID'),
                      value: _biometricsEnabled,
                      onChanged: _saving ? null : _setBiometrics,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _matched && !_saving ? _save : null,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'Saving…' : 'Continue'),
                    ),
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
