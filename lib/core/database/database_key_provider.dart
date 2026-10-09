import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseKeyProvider {
  DatabaseKeyProvider(
    this.firebaseUid, {
    FlutterSecureStorage? secureStorage,
    FirebaseFirestore? firestore,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _firestore = firestore ?? FirebaseFirestore.instance;

  static const _keyLengthBytes = 32;
  static const _keyVersion = 1;
  static const _secureStoragePrefix = 'chronologe_database_key_v2_';

  final String firebaseUid;
  final FlutterSecureStorage _secureStorage;
  final FirebaseFirestore _firestore;

  Future<String> getKey() async {
    if (firebaseUid.isEmpty) {
      throw StateError('A signed-in Firebase user is required.');
    }

    final localKey = await _secureStorage.read(key: _localStorageKey);
    if (_isValidKey(localKey)) return localKey!;

    final keyDocument = _firestore
        .collection('users')
        .doc(firebaseUid)
        .collection('private')
        .doc('databaseKey');
    final remoteSnapshot = await keyDocument.get();
    final remoteKey = remoteSnapshot.data()?['cipherKey'];
    if (_isValidKey(remoteKey)) {
      await _secureStorage.write(
        key: _localStorageKey,
        value: remoteKey! as String,
      );
      return remoteKey;
    }

    final generatedKey = _generateKey();
    try {
      await keyDocument.set({
        'cipherKey': generatedKey,
        'keyVersion': _keyVersion,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // Another device may have won the create race. Updates are denied by rules,
      // so read back the winning immutable key before surfacing an error.
      final winningSnapshot = await keyDocument.get();
      final winningKey = winningSnapshot.data()?['cipherKey'];
      if (!_isValidKey(winningKey)) rethrow;
      await _secureStorage.write(
        key: _localStorageKey,
        value: winningKey! as String,
      );
      return winningKey;
    }

    await _secureStorage.write(key: _localStorageKey, value: generatedKey);
    return generatedKey;
  }

  String get _localStorageKey {
    final encodedUid = base64UrlEncode(utf8.encode(firebaseUid))
        .replaceAll('=', '');
    return '$_secureStoragePrefix$encodedUid';
  }

  String _generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      _keyLengthBytes,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes);
  }

  bool _isValidKey(Object? key) {
    if (key is! String || key.isEmpty) return false;
    try {
      return base64Url.decode(key).length == _keyLengthBytes;
    } on FormatException {
      return false;
    }
  }
}
