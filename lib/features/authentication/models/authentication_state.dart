import 'auth_mode.dart';

class AuthenticationState {
  const AuthenticationState({
    this.mode = AuthMode.signIn,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthMode mode;
  final bool isLoading;
  final String? errorMessage;

  AuthenticationState copyWith({
    AuthMode? mode,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthenticationState(
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
