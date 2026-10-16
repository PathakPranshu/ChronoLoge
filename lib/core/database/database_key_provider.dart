import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseKeyProvider {
  DatabaseKeyProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  static const _storageKey = 'chronologe_database_key_v1';
  static const _keyLengthBytes = 32;

  final FlutterSecureStorage _storage;

  // Returns the stored SQLCipher key or securely creates one for a new database.
  Future<String> getOrCreateKey({required bool hasExistingDatabase}) async {
    final existingKey = await _storage.read(key: _storageKey);
    if (_isValidKey(existingKey)) return existingKey!;

    if (existingKey != null && existingKey.isNotEmpty) {
      throw StateError('The stored database encryption key is invalid.');
    }

    if (hasExistingDatabase) {
      throw StateError(
        'The database exists, but its encryption key is missing. '
        'Restore the key or explicitly migrate/reset the database.',
      );
    }

    final random = Random.secure();
    final keyBytes = List<int>.generate(
      _keyLengthBytes,
      (_) => random.nextInt(256),
      growable: false,
    );
    final newKey = base64UrlEncode(keyBytes);
    await _storage.write(key: _storageKey, value: newKey);
    return newKey;
  }

  // Returns the current key for the signed-in user's cloud backup.
  Future<String> exportKey() async {
    final key = await _storage.read(key: _storageKey);
    if (!_isValidKey(key)) {
      throw StateError('The database encryption key could not be backed up.');
    }
    return key!;
  }

  // Restores a validated key before opening a downloaded database.
  Future<void> importKey(String key) async {
    if (!_isValidKey(key)) {
      throw StateError('The backup contains an invalid database key.');
    }
    await _storage.write(key: _storageKey, value: key);
  }

  bool _isValidKey(String? key) {
    if (key == null || key.isEmpty) return false;
    try {
      return base64Url.decode(key).length == _keyLengthBytes;
    } on FormatException {
      return false;
    }
  }
}
