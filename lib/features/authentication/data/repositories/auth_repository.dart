import 'package:chronologe/core/database/user_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import '../secure_storage_service.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final LocalAuthentication _localAuth;
  final SecureStorageService _secureStorage;
  final UserDatabase? _userDatabase;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    LocalAuthentication? localAuth,
    SecureStorageService? secureStorage,
    UserDatabase? userDatabase,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _localAuth = localAuth ?? LocalAuthentication(),
       _secureStorage = secureStorage ?? SecureStorageService(),
       _userDatabase = userDatabase;

  /// Stream to listen to auth state changes (logged in or logged out)
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Stream to listen to user changes (name, email, password updates)
  Stream<User?> get userChanges => _firebaseAuth.userChanges();

  // Synchronizes Firebase User data to local encrypted SQLite
  Future<void> _syncToSqlite(User? user) async {
    if (user == null || _userDatabase == null) return;

    await _userDatabase.upsertUser(
      userId: user.uid,
      name: user.displayName ?? 'User',
      email: user.email ?? '',
    );
  }

  /// Handles Email and Password Login
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Internal data sync (e.g., create SQLite User record)
      await _syncToSqlite(credential.user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == "invalid-credential") {
        throw ('Email, or password is incorrect!');
      }
      throw ("Failed to login. Try again!");
    } catch (e) {
      throw 'An unexpected error occurred during login.';
    }
  }

  /// Google Sign in Flow
  Future<bool> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      // Handle the case where the user cancels the sign-in modal
      if (googleUser == null) return false;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      // Internal data sync (e.g., create SQLite User record)
      await _syncToSqlite(userCredential.user);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return false;
      }
      throw 'Google Sign-In failed. Please try again.';
    } catch (e) {
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  /// Handles User Registration
  Future<void> registerWithEmail(
    String name,
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      await user?.updateDisplayName(name);

      // Internal data sync (e.g., create SQLite User record)
      await _syncToSqlite(userCredential.user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw ('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        throw ('The account already exists for that email.');
      } else if (e.code == "invalid-email") {
        throw ('The email is invalid. Try again!');
      }
      throw ("Failed to register account. Try again!");
    } catch (e) {
      throw ("An unexpected error occurred during registration.");
    }
  }

  /// Sends a password reset link to the provided email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ??
          'Failed to send password reset email. Please try again.';
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }

  /// Signs the user out of Firebase and Google
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();

    // Clears the PIN and Biometric preferences
    await _secureStorage.clearSecurityData();
  }

  /// Re-authentication for email/password users
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw "No user currently signed in.";
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == "wrong-password" || e.code == "invalid-credential") {
        throw "Current password is incorrect.";
      }
      throw 'Re-authentication failed. Please try again.';
    }
  }

  /// Checks if the current user signed in using google
  bool isGoogleAuthUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;

    // Check if any of linked provider is google
    return user.providerData.any(
      (userInfo) => userInfo.providerId == "google.com",
    );
  }

  /// Update user display name
  Future<void> updateDisplayName(String newName) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw "No user currently signed in";
    try {
      await user.updateDisplayName(newName);

      // Reload the user to get updated data
      await user.reload();

      await _syncToSqlite(_firebaseAuth.currentUser);
    } catch (e) {
      throw "Failed to update name. Try Again!";
    }
  }

  /// Update the user signin email
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw "No user currently signed in";

    if (isGoogleAuthUser()) {
      throw 'Cannot change email for Google Sign-In accounts.';
    }

    try {
      await reauthenticateWithPassword(currentPassword);
      // Sends a verification link to the new email address.
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'This email is already associated with another account.';
      } else if (e.code == 'invalid-email') {
        throw 'Please enter a valid email address.';
      }
      throw 'Failed to update email. Try again!';
    }
  }

  /// Update signin password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw 'No user currently signed in.';

    if (isGoogleAuthUser()) {
      throw 'Cannot change password for Google Sign-In accounts.';
    }
    try {
      await reauthenticateWithPassword(currentPassword);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw 'The new password is too weak.';
      }
      throw 'Failed to update password. Try again!';
    }
  }

  /// Deletes the Firebase account and clears local security credentials
  Future<void> deleteAccount({String? currentPassword}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw 'No user currently signed in.';

    try {
      if (!isGoogleAuthUser() && currentPassword != null) {
        await reauthenticateWithPassword(currentPassword);
      }
      await user.delete();

      // Sign out the user and clear local security credential
      await signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign out and sign back in before deleting your account.';
      }
      throw 'Failed to delete account. Try again!';
    }
  }

  /* ---- BIOMETRICS SETUP ---- */

  /// Checks if the device supports hardware biometric authentication
  Future<bool> canUseBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  /// Triggers the OS-level FaceID / Fingerprint prompt
  Future<bool> authenticateWithBiometrics(
    String reason,
    String? siginTitle,
    String? cancelTitle,
  ) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: siginTitle,
            cancelButton: cancelTitle,
          ),
          IOSAuthMessages(cancelButton: cancelTitle),
        ],
        biometricOnly: true,
      );
    } catch (e) {
      return false;
    }
  }
}
