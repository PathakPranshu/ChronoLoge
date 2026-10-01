import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'diary_database.dart';
import 'settings_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final diaryDatabaseProvider = Provider<DiaryDatabase>((ref) {
  return DiaryDatabase(ref.watch(appDatabaseProvider));
});

final settingsDatabaseProvider = Provider<SettingsDatabase>((ref) {
  return SettingsDatabase(ref.watch(appDatabaseProvider));
});
