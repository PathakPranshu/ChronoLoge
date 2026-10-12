import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? _initSecureStorage();

  static const _pinKey = 'chronologe_secure_pin';
  static const _biometricKey = 'chronologe_use_biometric';

  static FlutterSecureStorage _initSecureStorage() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions.defaultOptions,
      iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device
    ));
  }

  /// Saves the 4-digit PIN securely
  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  /// Verifies if the provided PIN matches the stored PIN
  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == pin;
  }

  /// Checks if a PIN has been set up previously
  Future<bool> hasPin() async {
    return await _storage.containsKey(key: _pinKey);
  }

  /// Saves the user's preference for biometric unlock
  Future<void> setBiometricPreference(bool isEnabled) async {
    await _storage.write(key: _biometricKey, value: isEnabled.toString());
  }

  /// Retrieves the user's biometric preference
  Future<bool> getBiometricPreference() async {
    final value = await _storage.read(key: _biometricKey);
    return value == 'true';
  }

  /// Clears security data (called during account deletion or logout)
  Future<void> clearSecurityData() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _biometricKey);
  }
}
