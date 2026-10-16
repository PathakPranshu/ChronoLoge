import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../database/database_constants.dart';
import '../database/diary_database.dart';
import '../services/media_encryption_service.dart';

class CloudBackupInfo {
  const CloudBackupInfo({required this.createdAt, required this.mediaCount});

  final DateTime createdAt;
  final int mediaCount;
}

/// Uploads and restores one private backup for the signed-in user.
class CloudBackupService {
  CloudBackupService({
    required this.appDatabase,
    required this.diaryDatabase,
    required this.mediaEncryption,
    FirebaseAuth? firebaseAuth,
    FirebaseStorage? firebaseStorage,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance;

  static const _backupVersion = 2;
  static const _maximumMetadataBytes = 2 * 1024 * 1024;

  final AppDatabase appDatabase;
  final DiaryDatabase diaryDatabase;
  final MediaEncryptionService mediaEncryption;
  final FirebaseAuth _firebaseAuth;
  final FirebaseStorage _firebaseStorage;

  // Reads the small latest-backup pointer without downloading diary data.
  Future<CloudBackupInfo?> getLatestBackup() async {
    final user = _requireUser();
    try {
      final bytes = await _latestReference(user.uid).getData(4096);
      if (bytes == null) return null;
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
      if (createdAt == null) return null;
      return CloudBackupInfo(
        createdAt: createdAt.toLocal(),
        mediaCount: json['mediaCount'] as int? ?? 0,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return null;
      rethrow;
    }
  }

  // Uploads a database snapshot, encrypted media, and private backup metadata.
  Future<CloudBackupInfo> backUp({
    void Function(double progress)? onProgress,
  }) async {
    final user = _requireUser();
    final createdAt = DateTime.now().toUtc();
    final backupId = createdAt.microsecondsSinceEpoch.toString();
    final backupReference = _backupRoot(user.uid).child(backupId);
    final mediaFiles = <File>[];
    final mediaLocations = await diaryDatabase.getAllMediaLocations();
    await mediaEncryption.encryptFiles(mediaLocations);
    for (final location in mediaLocations) {
      final file = File(location);
      if (await file.exists()) mediaFiles.add(file);
    }
    final snapshot = await appDatabase.createBackupSnapshot();

    final totalSteps = mediaFiles.length + 3;
    var completedSteps = 0;
    void stepComplete() {
      completedSteps++;
      onProgress?.call(completedSteps / totalSteps);
    }

    var completed = false;
    try {
      onProgress?.call(0);
      await backupReference
          .child('database.bin')
          .putFile(
            snapshot,
            SettableMetadata(contentType: 'application/octet-stream'),
          );
      stepComplete();

      final mediaRecords = <Map<String, Object?>>[];
      for (var index = 0; index < mediaFiles.length; index++) {
        final file = mediaFiles[index];
        final extension = path.extension(file.path).toLowerCase();
        final objectName =
            '${index.toString().padLeft(6, '0')}'
            '${extension.isEmpty ? '.bin' : extension}';
        await backupReference
            .child('media/$objectName')
            .putFile(
              file,
              SettableMetadata(contentType: 'application/octet-stream'),
            );
        mediaRecords.add({'oldPath': file.path, 'object': objectName});
        stepComplete();
      }

      final metadata = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': _backupVersion,
            'databaseVersion': DatabaseConstants.version,
            'firebaseUid': user.uid,
            'createdAt': createdAt.toIso8601String(),
            'databaseKey': await appDatabase.exportEncryptionKey(),
            'mediaKey': await mediaEncryption.exportKey(),
            'media': mediaRecords,
          }),
        ),
      );
      await backupReference
          .child('metadata.json')
          .putData(metadata, SettableMetadata(contentType: 'application/json'));
      stepComplete();

      final pointer = utf8.encode(
        jsonEncode({
          'version': _backupVersion,
          'backupId': backupId,
          'createdAt': createdAt.toIso8601String(),
          'mediaCount': mediaFiles.length,
        }),
      );
      await _latestReference(user.uid).putData(
        Uint8List.fromList(pointer),
        SettableMetadata(contentType: 'application/json'),
      );
      stepComplete();
      completed = true;
      try {
        await _deleteOlderBackups(user.uid, keepBackupId: backupId);
      } on FirebaseException {
        // The new backup is already complete; stale cleanup can wait.
      }
      return CloudBackupInfo(
        createdAt: createdAt.toLocal(),
        mediaCount: mediaFiles.length,
      );
    } finally {
      if (await snapshot.exists()) await snapshot.delete();
      if (!completed) {
        try {
          await _deleteTree(backupReference);
        } on FirebaseException {
          // Preserve the original upload error if staging cleanup also fails.
        }
      }
    }
  }

  // Downloads the latest backup and replaces the current local diary.
  Future<CloudBackupInfo> restore({
    void Function(double progress)? onProgress,
  }) async {
    final user = _requireUser();
    final pointerBytes = await _latestReference(user.uid).getData(4096);
    if (pointerBytes == null) throw StateError('No cloud backup was found.');
    final pointer =
        jsonDecode(utf8.decode(pointerBytes)) as Map<String, dynamic>;
    final backupId = pointer['backupId'] as String?;
    if (backupId == null || backupId.isEmpty) {
      throw StateError('The cloud backup information is invalid.');
    }

    final backupReference = _backupRoot(user.uid).child(backupId);
    Uint8List? metadataBytes;
    try {
      metadataBytes = await backupReference
          .child('metadata.json')
          .getData(_maximumMetadataBytes);
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        throw StateError(
          'This backup uses the old recovery-password format. '
          'Create a new cloud backup first.',
        );
      }
      rethrow;
    }
    if (metadataBytes == null) {
      throw StateError('The backup information is missing.');
    }
    final bundle = _decodeMetadata(metadataBytes);
    if (bundle['version'] != _backupVersion ||
        bundle['firebaseUid'] != user.uid ||
        bundle['databaseVersion'] != DatabaseConstants.version) {
      throw StateError('This backup is not compatible with the current app.');
    }
    final backedUpAt = DateTime.tryParse(bundle['createdAt'] as String? ?? '');
    if (backedUpAt == null) {
      throw StateError('The backup information is damaged.');
    }

    final mediaRecords = (bundle['media'] as List<Object?>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final totalSteps = mediaRecords.length + 2;
    var completedSteps = 0;
    void stepComplete() {
      completedSteps++;
      onProgress?.call(completedSteps / totalSteps);
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final databaseDownload = File(
      path.join(temporaryDirectory.path, 'chronologe_restore_$backupId.db'),
    );
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final restoredMediaDirectory = Directory(
      path.join(documentsDirectory.path, 'restored_media', backupId),
    );
    await restoredMediaDirectory.create(recursive: true);
    final restoredPaths = <String, String>{};
    final oldMediaKey = await mediaEncryption.exportKey();

    try {
      onProgress?.call(0);
      await backupReference.child('database.bin').writeToFile(databaseDownload);
      stepComplete();

      for (final record in mediaRecords) {
        final oldPath = record['oldPath'] as String?;
        final objectName = record['object'] as String?;
        if (oldPath == null || objectName == null) {
          throw StateError('The media backup information is invalid.');
        }
        final restoredFile = File(
          path.join(restoredMediaDirectory.path, objectName),
        );
        await backupReference
            .child('media/$objectName')
            .writeToFile(restoredFile);
        restoredPaths[oldPath] = restoredFile.path;
        stepComplete();
      }

      await mediaEncryption.importKey(bundle['mediaKey'] as String? ?? '');
      await appDatabase.restoreBackup(
        backupFile: databaseDownload,
        databaseKey: bundle['databaseKey'] as String? ?? '',
        mediaPaths: restoredPaths,
      );
      stepComplete();
      return CloudBackupInfo(
        createdAt: backedUpAt.toLocal(),
        mediaCount: restoredPaths.length,
      );
    } catch (_) {
      await mediaEncryption.importKey(oldMediaKey);
      if (await restoredMediaDirectory.exists()) {
        await restoredMediaDirectory.delete(recursive: true);
      }
      rethrow;
    } finally {
      if (await databaseDownload.exists()) await databaseDownload.delete();
    }
  }

  Map<String, dynamic> _decodeMetadata(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on Object {
      throw StateError('The backup information is damaged.');
    }
  }

  FirebaseAuth get _auth => _firebaseAuth;

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before using cloud backup.');
    return user;
  }

  Reference _backupRoot(String uid) =>
      _firebaseStorage.ref('users/$uid/backups');

  Reference _latestReference(String uid) =>
      _backupRoot(uid).child('latest.json');

  Future<void> _deleteOlderBackups(
    String uid, {
    required String keepBackupId,
  }) async {
    final contents = await _backupRoot(uid).listAll();
    for (final prefix in contents.prefixes) {
      if (prefix.name != keepBackupId) await _deleteTree(prefix);
    }
  }

  Future<void> _deleteTree(Reference reference) async {
    try {
      final contents = await reference.listAll();
      for (final item in contents.items) {
        await item.delete();
      }
      for (final prefix in contents.prefixes) {
        await _deleteTree(prefix);
      }
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
