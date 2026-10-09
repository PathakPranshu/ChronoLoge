import 'dart:convert';

abstract final class DatabaseConstants {
  static const version = 2;

  static String nameForUser(String firebaseUid) {
    final encodedUid = base64UrlEncode(utf8.encode(firebaseUid))
        .replaceAll('=', '');
    return 'chronologe_$encodedUid.db';
  }
}

abstract final class DiaryEntriesTable {
  static const name = 'diary_entries';
  static const date = 'date';
  static const title = 'title';
  static const textData = 'text_data';
  static const mood = 'mood';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

abstract final class DiaryImagesTable {
  static const name = 'diary_images';
  static const id = 'id';
  static const entryDate = 'entry_date';
  static const imageLocation = 'image_location';
  static const sortOrder = 'sort_order';
}

abstract final class SettingsTable {
  static const name = 'settings';
  static const setting = 'setting';
  static const value = 'value';
}
