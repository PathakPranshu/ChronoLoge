import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/secure_storage_provider.dart';
import '../pin_setup_state.dart';

final pinSetupViewModelProvider =
    NotifierProvider.autoDispose<PinSetupViewModel, PinSetupState>(() {
  return PinSetupViewModel();
});

class PinSetupViewModel extends Notifier<PinSetupState> {
  @override
  PinSetupState build() {
    _checkBiometricSupport();
    return const PinSetupState();
  }

  Future<void> _checkBiometricSupport() async {
    final authRepo = ref.read(authRepositoryProvider);
    final isSupported = await authRepo.canUseBiometrics();
    
    state = state.copyWith(biometricsSupported: isSupported);
  }

  void addDigit(int digit) {
    if (state.isSaving || state.currentInput.length >= 4) return;

    final newInput = state.currentInput + digit.toString();
    
    bool isMatched = false;
    bool hasError = false;
    String? errorMessage;

    // Validate confirmation instantly as they type the 4th digit
    if (state.step == PinSetupStep.confirm && newInput.length == 4) {
      if (newInput == state.firstPin) {
        isMatched = true;
      } else {
        hasError = true;
        errorMessage = "PINs do not match. Please try again.";
      }
    }

    state = state.copyWith(
      currentInput: newInput,
      hasError: hasError,
      errorMessage: errorMessage,
      isMatched: isMatched,
    );

    // Auto-advance to Confirm step once 4 digits are typed in Create step
    if (state.step == PinSetupStep.create && newInput.length == 4) {
      Future.delayed(const Duration(milliseconds: 250), () {
        state = state.copyWith(
          step: PinSetupStep.confirm,
          firstPin: newInput,
          currentInput: '',
        );
      });
    } else if (hasError) {
      // Clear error automatically after a short delay so they can try again
      Future.delayed(const Duration(milliseconds: 800), () {
        state = state.copyWith(currentInput: '', hasError: false, errorMessage: null);
      });
    }
  }

  void removeDigit() {
    // Prevent removing digits if the PIN is being saved
    if (state.isSaving) return;

    if (state.currentInput.isEmpty) {
      if (state.step == PinSetupStep.confirm) {
        state = state.copyWith(
          step: PinSetupStep.create,
          firstPin: '',
          hasError: false,
          errorMessage: null,
        );
      }
      return;
    }

    state = state.copyWith(
      currentInput: state.currentInput.substring(0, state.currentInput.length - 1),
      hasError: false,
      isMatched: false,
      errorMessage: null,
    );
  }

  Future<bool> enableBiometrics() async {
    final authRepo = ref.read(authRepositoryProvider);
    final didAuthenticate = await authRepo.authenticateWithBiometrics(
      "Authenticate to enable biometric unlock for ChronoLoge",
      "Authentication required",
      "Cancel"
    );

    if (didAuthenticate) {
      state = state.copyWith(biometricsEnabled: true);
      return true;
    }
    return false;
  }

  void disableBiometrics() {
    state = state.copyWith(biometricsEnabled: false);
  }

  Future<bool> finalizeSetup() async {
    if (!state.isMatched) return false;
    state = state.copyWith(isSaving: true);

    try {
      final secureStorage = ref.read(secureStorageProvider);
      
      await secureStorage.savePin(state.firstPin);
      await secureStorage.setBiometricPreference(state.biometricsEnabled);
      
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        hasError: true,
        errorMessage: "Failed to secure device. Please try again.",
      );
      return false;
    }
  }
}