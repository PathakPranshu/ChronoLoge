import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/shared/providers/auth_provider.dart';
import '../../../authentication/shared/providers/secure_storage_provider.dart';

class PrivacySecurityState {
  final bool isBiometricEnabled;
  final bool isBiometricAvailable;

  const PrivacySecurityState({
    this.isBiometricEnabled = false,
    this.isBiometricAvailable = false,
  });

  PrivacySecurityState copyWith({
    bool? isBiometricEnabled,
    bool? isBiometricAvailable,
  }) {
    return PrivacySecurityState(
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
    );
  }
}

final privacySecurityViewModelProvider =
    AsyncNotifierProvider<PrivacySecurityViewModel, PrivacySecurityState>(
  PrivacySecurityViewModel.new,
);

class PrivacySecurityViewModel extends AsyncNotifier<PrivacySecurityState> {
  @override
  FutureOr<PrivacySecurityState> build() async {
    final authRepo = ref.read(authRepositoryProvider);
    final secureStorage = ref.read(secureStorageProvider);

    final isAvailable = await authRepo.canUseBiometrics();
    final isEnabled = isAvailable
        ? await secureStorage.getBiometricPreference()
        : false;

    return PrivacySecurityState(
      isBiometricEnabled: isEnabled,
      isBiometricAvailable: isAvailable,
    );
  }

  /// Returns an error message string if the toggle fails, or null on success.
  Future<String?> toggleBiometrics(bool enable) async {
    final current = state.value;
    if (current == null) return null;

    final authRepo = ref.read(authRepositoryProvider);
    final secureStorage = ref.read(secureStorageProvider);

    if (enable) {
      if (!current.isBiometricAvailable) {
        return 'Biometric authentication is not available on this device.';
      }

      // Verify biometric hardware before enabling
      final authenticated = await authRepo.authenticateWithBiometrics(
        'Authenticate to enable biometric unlock',
        'Enable Biometric Unlock',
        'Cancel',
      );

      if (!authenticated) {
        return 'Biometric verification was cancelled or failed.';
      }
    }

    // Optimistic update
    state = AsyncData(current.copyWith(isBiometricEnabled: enable));

    try {
      await secureStorage.setBiometricPreference(enable);
      return null;
    } catch (_) {
      state = AsyncData(current);
      return 'Could not update biometric preference. Please try again.';
    }
  }
}