import 'package:sqflite_sqlcipher/sqflite.dart';

import 'app_database.dart';
import 'database_constants.dart';

class SettingsDatabase {
  // Creates a settings data-access layer backed by the shared app database.
  const SettingsDatabase(this._appDatabase);

  final AppDatabase _appDatabase;

  // Returns the value for a setting, or null when the setting does not exist.
  Future<String?> getSetting(String settingName) async {
    _validateSettingName(settingName);
    final database = await _appDatabase.database;
    final rows = await database.query(
      SettingsTable.name,
      columns: [SettingsTable.value],
      where: '${SettingsTable.setting} = ?',
      whereArgs: [settingName],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.single[SettingsTable.value]! as String;
  }

  // Changes an existing setting without creating a missing setting.
  Future<void> changeSetting(String settingName, String value) async {
    _validateSettingName(settingName);
    final database = await _appDatabase.database;
    await database.update(
      SettingsTable.name,
      {SettingsTable.value: value},
      where: '${SettingsTable.setting} = ?',
      whereArgs: [settingName],
    );
  }

  // Adds a new setting and throws when the setting already exists.
  Future<void> addSetting(String settingName, String value) async {
    _validateSettingName(settingName);
    final database = await _appDatabase.database;
    await database.insert(SettingsTable.name, {
      SettingsTable.setting: settingName,
      SettingsTable.value: value,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // Deletes a setting when it exists.
  Future<void> deleteSetting(String settingName) async {
    _validateSettingName(settingName);
    final database = await _appDatabase.database;
    await database.delete(
      SettingsTable.name,
      where: '${SettingsTable.setting} = ?',
      whereArgs: [settingName],
    );
  }

  // Rejects blank setting names before they reach the database.
  void _validateSettingName(String settingName) {
    if (settingName.trim().isEmpty) {
      throw ArgumentError.value(
        settingName,
        'settingName',
        'Setting name cannot be empty.',
      );
    }
  }
}
