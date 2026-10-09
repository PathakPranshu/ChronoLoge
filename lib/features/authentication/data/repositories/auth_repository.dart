import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';

// Import your services and models here

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final LocalAuthentication _localAuth;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    LocalAuthentication? localAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _localAuth = localAuth ?? LocalAuthentication();

  /// Stream to listen to auth state changes (logged in or logged out)
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Handles Email and Password Login
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Internal data sync (e.g., upsert local SQLite User table)
      // await _syncToSqlite(credential.user);
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

      // Internal data sync (e.g., upsert local SQLite User table)
      // await _syncToSqlite(userCredential.user);

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
      // await _syncToSqlite(userCredential.user);
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
  }
}
