abstract final class DatabaseConstants {
  static const name = 'chronologe.db';
  static const version = 3;
}

abstract final class UserTable {
  static const name = 'user';
  static const userId = 'user_id';
  static const nameCol = 'name';
  static const email = 'email';
}

abstract final class DiaryEntriesTable {
  static const name = 'diary_entries';
  static const date = 'date';
  static const title = 'title';
  static const textData = 'text_data';
  static const mood = 'mood';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}

abstract final class DiaryImagesTable {
  static const name = 'diary_images';
  static const id = 'id';
  static const entryDate = 'entry_date';
  static const imageLocation = 'image_location';
  static const sortOrder = 'sort_order';
}

abstract final class DiaryDraftsTable {
  static const name = 'diary_drafts';
  static const date = 'date';
  static const title = 'title';
  static const textData = 'text_data';
  static const mood = 'mood';
  static const imagesData = 'images_data';
  static const status = 'status';
  static const failureReason = 'failure_reason';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';

  static const unfinished = 'unfinished';
  static const unsaved = 'unsaved';
}

abstract final class SettingsTable {
  static const name = 'settings';
  static const setting = 'setting';
  static const value = 'value';
}
