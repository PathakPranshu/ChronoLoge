import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

class CloudBackupService {
  CloudBackupService({
    required this.firebaseUid,
    required this.appDatabase,
    FirebaseAuth? firebaseAuth,
    FirebaseStorage? firebaseStorage,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance;

  static const _lastBackupPrefix = 'last_cloud_backup_utc_v1_';

  final String firebaseUid;
  final AppDatabase appDatabase;
  final FirebaseAuth _firebaseAuth;
  final FirebaseStorage _firebaseStorage;

  Reference get _backupReference =>
      _firebaseStorage.ref('users/$firebaseUid/backups/latest.db');

  Future<DateTime?> getLastBackupAt() async {
    final preferences = await SharedPreferences.getInstance();
    final localValue = preferences.getString('$_lastBackupPrefix$firebaseUid');
    final localDate = DateTime.tryParse(localValue ?? '');
    if (localDate != null) return localDate;

    try {
      final metadata = await _backupReference.getMetadata();
      final cloudValue = metadata.customMetadata?['backedUpAtUtc'];
      final cloudDate = DateTime.tryParse(cloudValue ?? '');
      if (cloudDate != null) {
        await preferences.setString(
          '$_lastBackupPrefix$firebaseUid',
          cloudDate.toIso8601String(),
        );
      }
      return cloudDate;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return null;
      rethrow;
    }
  }

  Future<DateTime> uploadCurrentDatabase({
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);

    final signedInUser = _firebaseAuth.currentUser;
    if (signedInUser == null || signedInUser.uid != firebaseUid) {
      throw StateError('The active database does not belong to this user.');
    }
    if (appDatabase.firebaseUid != firebaseUid) {
      throw StateError('The selected database does not belong to this user.');
    }

    // Open once so a brand-new account gets its own database before copying it.
    await appDatabase.database;
    await appDatabase.close();

    final sourceFile = File(await appDatabase.filePath);
    final temporaryDirectory = await getTemporaryDirectory();
    final snapshotFile = File(
      path.join(
        temporaryDirectory.path,
        'chronologe_backup_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );

    try {
      if (!await sourceFile.exists()) {
        throw StateError('The current user database could not be found.');
      }

      await sourceFile.copy(snapshotFile.path);

      // Reopen immediately; the network upload may take a while.
      await appDatabase.database;

      final backedUpAt = DateTime.now().toUtc();
      final uploadTask = _backupReference.putFile(
        snapshotFile,
        SettableMetadata(
          contentType: 'application/octet-stream',
          customMetadata: {
            'backedUpAtUtc': backedUpAt.toIso8601String(),
            'databaseVersion': '2',
          },
        ),
      );
      final progressSubscription = uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes <= 0) return;
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      });

      try {
        await uploadTask;
        onProgress?.call(1);
      } finally {
        await progressSubscription.cancel();
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        '$_lastBackupPrefix$firebaseUid',
        backedUpAt.toIso8601String(),
      );
      return backedUpAt;
    } finally {
      // Ensure the application database is usable even if copy/upload fails.
      await appDatabase.database;
      if (await snapshotFile.exists()) {
        await snapshotFile.delete();
      }
    }
  }
}
