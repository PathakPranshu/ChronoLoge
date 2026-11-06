
import '../../../../core/database/settings_database.dart';

class SettingsRepository {
  const SettingsRepository(this._settingsDatabase);

  final SettingsDatabase _settingsDatabase;

  Future<String?> getSetting(String key) {
    return _settingsDatabase.getSetting(key);
  }

  Future<void> saveSetting(String key, String value) async {
    final existingValue = await _settingsDatabase.getSetting(key);

    if (existingValue == null) {
      await _settingsDatabase.addSetting(key, value);
    } else {
      await _settingsDatabase.changeSetting(key, value);
    }
  }

  Future<void> deleteSetting(String key) {
    return _settingsDatabase.deleteSetting(key);
  }
}
