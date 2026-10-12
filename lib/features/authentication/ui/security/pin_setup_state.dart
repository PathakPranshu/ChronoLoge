enum PinSetupStep { create, confirm }

class PinSetupState {
  final PinSetupStep step;
  final String firstPin;
  final String currentInput;
  final bool hasError;
  final String? errorMessage;
  final bool biometricsSupported;
  final bool biometricsEnabled;
  final bool isSaving;
  final bool isMatched;

  const PinSetupState({
    this.step = PinSetupStep.create,
    this.firstPin = '',
    this.currentInput = '',
    this.hasError = false,
    this.errorMessage,
    this.biometricsSupported = false,
    this.biometricsEnabled = false,
    this.isSaving = false,
    this.isMatched = false,
  });

  PinSetupState copyWith({
    PinSetupStep? step,
    String? firstPin,
    String? currentInput,
    bool? hasError,
    String? errorMessage,
    bool? biometricsSupported,
    bool? biometricsEnabled,
    bool? isSaving,
    bool? isMatched,
  }) {
    return PinSetupState(
      step: step ?? this.step,
      firstPin: firstPin ?? this.firstPin,
      currentInput: currentInput ?? this.currentInput,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage, 
      biometricsSupported: biometricsSupported ?? this.biometricsSupported,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      isSaving: isSaving ?? this.isSaving,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}