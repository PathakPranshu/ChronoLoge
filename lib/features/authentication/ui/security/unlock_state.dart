class UnlockState {
  final String currentInput;
  final bool hasError;
  final bool biometricsEnabled;
  final bool isLoading;
  final bool isUnlocked;
  final String userName;

  const UnlockState({
    this.currentInput = '',
    this.hasError = false,
    this.biometricsEnabled = false,
    this.isLoading = false,
    this.isUnlocked = false,
    this.userName = '',
  });

  UnlockState copyWith({
    String? currentInput,
    bool? hasError,
    bool? biometricsEnabled,
    bool? isLoading,
    bool? isUnlocked,
    String? userName,
  }) {
    return UnlockState(
      currentInput: currentInput ?? this.currentInput,
      hasError: hasError ?? this.hasError,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      isLoading: isLoading ?? this.isLoading,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      userName: userName ?? this.userName,
    );
  }
}