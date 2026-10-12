import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/secure_storage_provider.dart';
import '../unlock_state.dart';

final unlockViewModelProvider =
    NotifierProvider.autoDispose<UnlockViewModel, UnlockState>(() {
  return UnlockViewModel();
});

class UnlockViewModel extends Notifier<UnlockState> {
  Timer? _errorResetTimer;

  @override
  UnlockState build() {
    ref.onDispose(() {
      _errorResetTimer?.cancel();
    });
    
    _initialize();
    return const UnlockState();
  }

  Future<void> _initialize() async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.authStateChanges.first;
    final name = user?.displayName?.split(' ').first ?? 'User';

    final secureStorage = ref.read(secureStorageProvider);
    final hasBiometrics = await secureStorage.getBiometricPreference();

    state = state.copyWith(
      userName: name,
      biometricsEnabled: hasBiometrics,
    );
  }

  Future<bool> promptBiometrics() async {
    final authRepo = ref.read(authRepositoryProvider);
    final success = await authRepo.authenticateWithBiometrics(
      "Unlock to view your memories",
      "Unlock ChronoLoge",
      "Use PIN Instead"
    );
    
    if (success) {
      state = state.copyWith(isUnlocked: true);
    }
    return success;
  }

  void addDigit(int digit) {
    if (state.isLoading || state.isUnlocked || state.currentInput.length >= 4) return;

    final newInput = state.currentInput + digit.toString();

    state = state.copyWith(
      currentInput: newInput,
      hasError: false, 
    );

    _errorResetTimer?.cancel();

    if (newInput.length == 4) {
      _verifyPin(newInput);
    }
  }

  void removeDigit() {
    if (state.currentInput.isEmpty || state.isLoading || state.isUnlocked) return;

    state = state.copyWith(
      currentInput: state.currentInput.substring(0, state.currentInput.length - 1),
      hasError: false,
    );
  }

  Future<void> _verifyPin(String pin) async {
    state = state.copyWith(isLoading: true);
    
    final secureStorage = ref.read(secureStorageProvider);
    final isMatch = await secureStorage.verifyPin(pin);

    if (isMatch) {
      state = state.copyWith(isLoading: false, isUnlocked: true);
    } else {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
      );
      
      _errorResetTimer?.cancel();
      _errorResetTimer = Timer(const Duration(milliseconds: 600), () {
        state = state.copyWith(currentInput: '', hasError: false);
      });
    }
  }
}