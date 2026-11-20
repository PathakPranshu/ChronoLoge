import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/shared/providers/secure_storage_provider.dart';

enum ChangePinStep { verifyCurrent, createNew, confirmNew }

class ChangePinState {
  final ChangePinStep step;
  final String currentInput;
  final String verifiedCurrentPin;
  final String newPin;
  final bool hasError;
  final String? errorMessage;
  final bool isSaving;
  final bool isCompleted;

  const ChangePinState({
    this.step = ChangePinStep.verifyCurrent,
    this.currentInput = '',
    this.verifiedCurrentPin = '',
    this.newPin = '',
    this.hasError = false,
    this.errorMessage,
    this.isSaving = false,
    this.isCompleted = false,
  });

  ChangePinState copyWith({
    ChangePinStep? step,
    String? currentInput,
    String? verifiedCurrentPin,
    String? newPin,
    bool? hasError,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isSaving,
    bool? isCompleted,
  }) {
    return ChangePinState(
      step: step ?? this.step,
      currentInput: currentInput ?? this.currentInput,
      verifiedCurrentPin: verifiedCurrentPin ?? this.verifiedCurrentPin,
      newPin: newPin ?? this.newPin,
      hasError: hasError ?? this.hasError,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

final changePinViewModelProvider =
    NotifierProvider.autoDispose<ChangePinViewModel, ChangePinState>(
  ChangePinViewModel.new,
);

class ChangePinViewModel extends Notifier<ChangePinState> {
  bool _isDisposed = false;

  @override
  ChangePinState build() {
    _isDisposed = false;
    ref.onDispose(() => _isDisposed = true);
    return const ChangePinState();
  }

  Future<void> addDigit(int digit) async {
    if (state.isSaving || state.isCompleted || state.currentInput.length >= 4) {
      return;
    }

    final input = state.currentInput + digit.toString();
    state = state.copyWith(
      currentInput: input,
      hasError: false,
      clearErrorMessage: true,
    );

    if (input.length < 4) return;

    switch (state.step) {
      case ChangePinStep.verifyCurrent:
        await _handleVerifyCurrent(input);
      case ChangePinStep.createNew:
        _handleCreateNew(input);
      case ChangePinStep.confirmNew:
        await _handleConfirmNew(input);
    }
  }

  Future<void> _handleVerifyCurrent(String input) async {
    final secureStorage = ref.read(secureStorageProvider);
    final isValid = await secureStorage.verifyPin(input);
    if (_isDisposed) return;

    if (isValid) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (_isDisposed) return;
        state = state.copyWith(
          step: ChangePinStep.createNew,
          verifiedCurrentPin: input,
          currentInput: '',
        );
      });
    } else {
      _triggerError('Incorrect PIN. Please try again.');
    }
  }

  void _handleCreateNew(String input) {
    if (input == state.verifiedCurrentPin) {
      _triggerError('New PIN must be different from your current PIN.');
      return;
    }

    Future.delayed(const Duration(milliseconds: 250), () {
      if (_isDisposed) return;
      state = state.copyWith(
        step: ChangePinStep.confirmNew,
        newPin: input,
        currentInput: '',
      );
    });
  }

  Future<void> _handleConfirmNew(String input) async {
    if (input != state.newPin) {
      _triggerError('PINs do not match. Please try again.');
      return;
    }

    state = state.copyWith(isSaving: true);

    try {
      final secureStorage = ref.read(secureStorageProvider);
      await secureStorage.savePin(state.newPin);
      if (_isDisposed) return;

      state = state.copyWith(isSaving: false, isCompleted: true);
    } catch (_) {
      if (_isDisposed) return;
      state = state.copyWith(isSaving: false);
      _triggerError('Failed to save new PIN. Please try again.');
    }
  }

  void _triggerError(String message) {
    state = state.copyWith(hasError: true, errorMessage: message);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (_isDisposed) return;
      state = state.copyWith(
        currentInput: '',
        hasError: false,
        clearErrorMessage: true,
      );
    });
  }

  void removeDigit() {
    if (state.isSaving || state.isCompleted) return;

    if (state.currentInput.isEmpty) {
      if (state.step == ChangePinStep.confirmNew) {
        state = state.copyWith(
          step: ChangePinStep.createNew,
          newPin: '',
          hasError: false,
          clearErrorMessage: true,
        );
      }
      return;
    }

    state = state.copyWith(
      currentInput: state.currentInput.substring(
        0,
        state.currentInput.length - 1,
      ),
      hasError: false,
      clearErrorMessage: true,
    );
  }
}