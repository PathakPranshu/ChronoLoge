import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_providers.dart';
import 'cloud_backup_service.dart';

final cloudBackupServiceProvider = Provider.autoDispose
    .family<CloudBackupService, String>((ref, firebaseUid) {
      return CloudBackupService(
        firebaseUid: firebaseUid,
        appDatabase: ref.watch(appDatabaseProvider(firebaseUid)),
      );
    });
