import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'diary_database.dart';
import 'settings_database.dart';

final appDatabaseProvider = Provider.autoDispose.family<AppDatabase, String>((
  ref,
  firebaseUid,
) {
  final database = AppDatabase(firebaseUid: firebaseUid);
  ref.onDispose(database.close);
  return database;
});

final userDatabaseInitializationProvider = FutureProvider.autoDispose
    .family<void, String>((ref, firebaseUid) async {
      await ref.watch(appDatabaseProvider(firebaseUid)).database;
    });

final diaryDatabaseProvider = Provider.autoDispose
    .family<DiaryDatabase, String>((ref, firebaseUid) {
      return DiaryDatabase(ref.watch(appDatabaseProvider(firebaseUid)));
    });

final settingsDatabaseProvider = Provider.autoDispose
    .family<SettingsDatabase, String>((ref, firebaseUid) {
      return SettingsDatabase(ref.watch(appDatabaseProvider(firebaseUid)));
    });
