import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_lock_providers.dart';
import 'pin_setup_page.dart';

/// Settings controls for changing the PIN, biometrics, and locking immediately.
class AppLockSettingsCard extends ConsumerStatefulWidget {
  const AppLockSettingsCard({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<AppLockSettingsCard> createState() =>
      _AppLockSettingsCardState();
}

class _AppLockSettingsCardState extends ConsumerState<AppLockSettingsCard> {
  late Future<_AppLockStatus> _status = _loadStatus();
  bool _updatingBiometrics = false;

  Future<_AppLockStatus> _loadStatus() async {
    final service = ref.read(appLockServiceProvider);
    final values = await Future.wait([
      service.canUseBiometrics(),
      service.isBiometricEnabled(widget.userId),
    ]);
    return _AppLockStatus(
      biometricsSupported: values[0],
      biometricsEnabled: values[0] && values[1],
    );
  }

  @override
  void didUpdateWidget(covariant AppLockSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _status = _loadStatus();
  }

  Future<void> _changePin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) => PinSetupPage(
          userId: widget.userId,
          canCancel: true,
          onComplete: () => Navigator.of(pageContext).pop(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _status = _loadStatus());
  }

  Future<void> _setBiometrics(bool enabled) async {
    if (_updatingBiometrics) return;
    setState(() => _updatingBiometrics = true);
    final service = ref.read(appLockServiceProvider);
    var shouldEnable = enabled;
    if (enabled) {
      shouldEnable = await service.authenticate(
        'Confirm your identity to enable biometric unlock.',
      );
    }
    await service.setBiometricEnabled(widget.userId, shouldEnable);
    if (!mounted) return;
    setState(() {
      _updatingBiometrics = false;
      _status = _loadStatus();
    });
    if (enabled && !shouldEnable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric unlock was not enabled.')),
      );
    }
  }

  void _lockNow() {
    ref.read(appLockSessionProvider.notifier).lock();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<_AppLockStatus>(
        future: _status,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final status = snapshot.requireData;
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Change PIN'),
                subtitle: const Text('Replace your four-digit app-lock PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _changePin,
              ),
              if (status.biometricsSupported) ...[
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: const Text('Biometric unlock'),
                  subtitle: const Text('Use fingerprint or Face ID'),
                  value: status.biometricsEnabled,
                  onChanged: _updatingBiometrics ? null : _setBiometrics,
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_rounded),
                title: const Text('Lock now'),
                subtitle: const Text('Require your PIN or biometrics again'),
                onTap: _lockNow,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppLockStatus {
  const _AppLockStatus({
    required this.biometricsSupported,
    required this.biometricsEnabled,
  });

  final bool biometricsSupported;
  final bool biometricsEnabled;
}
