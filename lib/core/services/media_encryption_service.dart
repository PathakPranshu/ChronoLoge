import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Encrypts diary files and creates short-lived clear copies for playback.
class MediaEncryptionService {
  MediaEncryptionService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'chronologe_media_key_v1';
  static const _keyLengthBytes = 32;
  static const _fileHeader = <int>[0x43, 0x4c, 0x4d, 0x31]; // CLM1

  final FlutterSecureStorage _storage;
  final AesGcm _algorithm = AesGcm.with256bits();
  final Random _random = Random.secure();
  Future<SecretKey>? _keyFuture;
  Future<void>? _playbackCleanup;

  // Encrypts a media file in place, leaving already encrypted files untouched.
  Future<void> encryptFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists() || await _hasEncryptedHeader(file)) return;

    final clearBytes = await file.readAsBytes();
    final secretBox = await _algorithm.encrypt(
      clearBytes,
      secretKey: await _getOrCreateKey(),
    );
    final encryptedBytes = Uint8List.fromList([
      ..._fileHeader,
      ...secretBox.concatenation(),
    ]);
    await file.writeAsBytes(encryptedBytes, flush: true);
  }

  // Encrypts each existing file in a collection for plaintext migration.
  Future<void> encryptFiles(Iterable<String> filePaths) async {
    for (final filePath in filePaths.toSet()) {
      await encryptFile(filePath);
    }
  }

  // Returns clear media bytes without writing them back to persistent storage.
  Future<Uint8List> decryptBytes(String filePath) async {
    final storedBytes = await File(filePath).readAsBytes();
    if (!_startsWithHeader(storedBytes)) return storedBytes;

    final secretBox = SecretBox.fromConcatenation(
      storedBytes.sublist(_fileHeader.length),
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    return Uint8List.fromList(
      await _algorithm.decrypt(secretBox, secretKey: await _getOrCreateKey()),
    );
  }

  // Creates a temporary clear copy for players that require a file path.
  Future<String> createPlaybackCopy(String encryptedFilePath) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final playbackDirectory = Directory(
      path.join(temporaryDirectory.path, 'chronologe_media_playback'),
    );
    await playbackDirectory.create(recursive: true);
    await _clearStalePlaybackFiles(playbackDirectory);
    final extension = path.extension(encryptedFilePath);
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}'
        '$extension';
    final playbackFile = File(path.join(playbackDirectory.path, fileName));
    await playbackFile.writeAsBytes(
      await decryptBytes(encryptedFilePath),
      flush: true,
    );
    return playbackFile.path;
  }

  Future<void> _clearStalePlaybackFiles(Directory directory) async {
    return _playbackCleanup ??= _deleteStalePlaybackFiles(directory);
  }

  Future<void> _deleteStalePlaybackFiles(Directory directory) async {
    await for (final entity in directory.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } on FileSystemException {
          // A locked stale preview can be retried on a later launch.
        }
      }
    }
  }

  Future<SecretKey> _getOrCreateKey() async {
    return _keyFuture ??= _loadOrCreateKey();
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final storedKey = await _storage.read(key: _storageKey);
    final keyBytes = storedKey == null || storedKey.isEmpty
        ? List<int>.generate(
            _keyLengthBytes,
            (_) => _random.nextInt(256),
            growable: false,
          )
        : base64Url.decode(storedKey);
    if (keyBytes.length != _keyLengthBytes) {
      throw StateError('The stored media encryption key is invalid.');
    }
    if (storedKey == null || storedKey.isEmpty) {
      await _storage.write(key: _storageKey, value: base64UrlEncode(keyBytes));
    }
    return SecretKey(keyBytes);
  }

  Future<bool> _hasEncryptedHeader(File file) async {
    final handle = await file.open();
    try {
      return _startsWithHeader(await handle.read(_fileHeader.length));
    } finally {
      await handle.close();
    }
  }

  bool _startsWithHeader(List<int> bytes) {
    if (bytes.length < _fileHeader.length) return false;
    for (var index = 0; index < _fileHeader.length; index++) {
      if (bytes[index] != _fileHeader[index]) return false;
    }
    return true;
  }
}
