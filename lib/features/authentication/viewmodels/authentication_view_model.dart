import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/auth_mode.dart';
import '../models/authentication_state.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authenticatedUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final authenticationViewModelProvider =
    NotifierProvider<AuthenticationViewModel, AuthenticationState>(
      AuthenticationViewModel.new,
    );

class AuthenticationViewModel extends Notifier<AuthenticationState> {
  bool _googleSignInInitialized = false;

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  @override
  AuthenticationState build() => const AuthenticationState();

  void selectMode(AuthMode mode) {
    state = state.copyWith(mode: mode, clearError: true);
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _runAuthAction(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (password != confirmPassword) {
      state = state.copyWith(errorMessage: 'The passwords do not match.');
      return false;
    }

    return _runAuthAction(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _initializeGoogleSignIn();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuthentication = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuthentication.idToken,
      );
      await _auth.signInWithCredential(credential);
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(isLoading: false, clearError: true);
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: _googleErrorMessage(error),
      );
      return false;
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _firebaseErrorMessage(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google sign-in could not be completed.',
      );
      return false;
    }
  }

  Future<bool> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.signOut();
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not sign out. Please try again.',
      );
      return false;
    }

    if (_googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase is already signed out, so stale Google state must not
        // prevent the application from locking.
      }
    }

    state = const AuthenticationState();
    return true;
  }

  Future<bool> _runAuthAction(Future<UserCredential> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _firebaseErrorMessage(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignInInitialized) return;

    final iosClientId = Firebase.app().options.iosClientId;
    if (defaultTargetPlatform == TargetPlatform.iOS && iosClientId == null) {
      throw StateError('The iOS Google client ID has not been configured.');
    }

    await GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? iosClientId
          : null,
    );
    _googleSignInInitialized = true;
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'The email or password is incorrect.',
      'email-already-in-use' =>
        'An account already exists for this email address.',
      'weak-password' => 'Use a stronger password with at least 6 characters.',
      'user-disabled' => 'This account has been disabled.',
      'operation-not-allowed' =>
        'This sign-in method is not enabled in Firebase yet.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }

  String _googleErrorMessage(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in still needs its Firebase platform configuration.',
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in was interrupted. Please try again.',
      _ => error.description ?? 'Google sign-in could not be completed.',
    };
  }
}
