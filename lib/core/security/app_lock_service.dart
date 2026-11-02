import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Stores this device's app-lock settings and opens the system biometric prompt.
class AppLockService {
  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuthentication,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           ),
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;

  String _pinKey(String userId) => 'app_lock_pin_$userId';
  String _biometricKey(String userId) => 'app_lock_biometric_$userId';

  /// Returns whether this account already has a PIN on this device.
  Future<bool> hasPin(String userId) {
    return _storage.containsKey(key: _pinKey(userId));
  }

  /// Saves a four-digit PIN in the platform's encrypted keychain or keystore.
  Future<void> savePin(String userId, String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('The app-lock PIN must contain four digits.');
    }
    await _storage.write(key: _pinKey(userId), value: pin);
  }

  /// Checks an entered PIN against the PIN saved for this account.
  Future<bool> verifyPin(String userId, String pin) async {
    final savedPin = await _storage.read(key: _pinKey(userId));
    return savedPin != null && savedPin == pin;
  }

  /// Returns whether biometric unlock was enabled for this account.
  Future<bool> isBiometricEnabled(String userId) async {
    return await _storage.read(key: _biometricKey(userId)) == 'true';
  }

  /// Saves whether this account may use fingerprint or Face ID unlock.
  Future<void> setBiometricEnabled(String userId, bool enabled) {
    return _storage.write(
      key: _biometricKey(userId),
      value: enabled.toString(),
    );
  }

  /// Checks whether the device has enrolled biometrics available to the app.
  Future<bool> canUseBiometrics() async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) return false;
      if (!await _localAuthentication.canCheckBiometrics) return false;
      return (await _localAuthentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Shows the operating system's fingerprint or Face ID prompt.
  Future<bool> authenticate(String reason) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Removes this account's PIN and biometric preference from this device.
  Future<void> clear(String userId) async {
    await _storage.delete(key: _pinKey(userId));
    await _storage.delete(key: _biometricKey(userId));
  }
}
