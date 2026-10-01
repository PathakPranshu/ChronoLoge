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
    if (existingKey != null && existingKey.isNotEmpty) return existingKey;

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
}
