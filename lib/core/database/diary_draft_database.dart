import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'app_database.dart';
import 'database_constants.dart';

typedef DiaryDraftMap = Map<String, Object?>;

class DiaryDraftDatabase {
  const DiaryDraftDatabase(this._appDatabase);

  final AppDatabase _appDatabase;

  // Saves a new draft or updates the existing draft for the same date.
  Future<void> saveDraft({
    required String date,
    required String status,
    String title = '',
    String textData = '',
    String mood = '',
    List<String> imageLocations = const [],
    String? failureReason,
  }) async {
    if (status != DiaryDraftsTable.unfinished &&
        status != DiaryDraftsTable.unsaved) {
      throw ArgumentError.value(
        status,
        'status',
        'Must be unfinished or unsaved.',
      );
    }

    final database = await _appDatabase.database;

    await database.transaction((transaction) async {
      final existingRows = await transaction.query(
        DiaryDraftsTable.name,
        columns: [DiaryDraftsTable.createdAt],
        where: '${DiaryDraftsTable.date} = ?',
        whereArgs: [date],
        limit: 1,
      );

      final now = _timestamp();

      final createdAt = existingRows.isNotEmpty
          ? existingRows.single[DiaryDraftsTable.createdAt] as String
          : now;

      await transaction.insert(DiaryDraftsTable.name, {
        DiaryDraftsTable.date: date,
        DiaryDraftsTable.title: title,
        DiaryDraftsTable.textData: textData,
        DiaryDraftsTable.mood: mood,
        DiaryDraftsTable.imagesData: jsonEncode(imageLocations),
        DiaryDraftsTable.status: status,
        DiaryDraftsTable.failureReason: failureReason,
        DiaryDraftsTable.createdAt: createdAt,
        DiaryDraftsTable.updatedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  // Saves a draft as a diary dated today.
  // The original date is used only to find and remove the draft.
  // If a diary already exists today, its content is merged.
  // All operations happen in one transaction.
  Future<void> saveDraftAsDiary({
    required String date,
    required String title,
    required String textData,
    required String mood,
    required List<String> imageLocations,
  }) async {
    final database = await _appDatabase.database;
    final diaryDate = _todayDateKey();

    await database.transaction((transaction) async {
      // Confirm that the original draft still exists.
      final draftRows = await transaction.query(
        DiaryDraftsTable.name,
        columns: [DiaryDraftsTable.date],
        where: '${DiaryDraftsTable.date} = ?',
        whereArgs: [date],
        limit: 1,
      );

      if (draftRows.isEmpty) {
        throw StateError('This draft no longer exists.');
      }

      // Check whether a diary already exists for today's date.
      final diaryRows = await transaction.query(
        DiaryEntriesTable.name,
        where: '${DiaryEntriesTable.date} = ?',
        whereArgs: [diaryDate],
        limit: 1,
      );

      if (diaryRows.isNotEmpty &&
          diaryRows.single[DiaryEntriesTable.deletedAt] != null) {
        throw StateError(
          'Today\'s diary is in the Recycle Bin. Restore it before merging.',
        );
      }

      final now = _timestamp();

      if (diaryRows.isEmpty) {
        // Create a new diary dated today.
        await transaction.insert(DiaryEntriesTable.name, {
          DiaryEntriesTable.date: diaryDate,
          DiaryEntriesTable.title: title.trim(),
          DiaryEntriesTable.textData: textData.trim(),
          DiaryEntriesTable.mood: mood.trim(),
          DiaryEntriesTable.createdAt: now,
          DiaryEntriesTable.updatedAt: now,
        });
      } else {
        // Merge into today's existing diary.
        final existing = diaryRows.single;

        final existingTitle =
            (existing[DiaryEntriesTable.title] as String? ?? '').trim();
        final existingText =
            (existing[DiaryEntriesTable.textData] as String? ?? '').trim();
        final existingMood = (existing[DiaryEntriesTable.mood] as String? ?? '')
            .trim();

        final draftTitle = title.trim();
        final draftText = textData.trim();
        final draftMood = mood.trim();

        final mergedText = existingText.isEmpty
            ? draftText
            : draftText.isEmpty
            ? existingText
            : '$existingText\n\n$draftText';

        await transaction.update(
          DiaryEntriesTable.name,
          {
            DiaryEntriesTable.title: existingTitle.isEmpty
                ? draftTitle
                : existingTitle,
            DiaryEntriesTable.textData: mergedText,
            DiaryEntriesTable.mood: existingMood.isEmpty
                ? draftMood
                : existingMood,
            DiaryEntriesTable.updatedAt: now,
          },
          where: '${DiaryEntriesTable.date} = ?',
          whereArgs: [diaryDate],
        );
      }

      // Read existing image references for today's diary.
      final existingImageRows = await transaction.query(
        DiaryImagesTable.name,
        columns: [DiaryImagesTable.imageLocation, DiaryImagesTable.sortOrder],
        where: '${DiaryImagesTable.entryDate} = ?',
        whereArgs: [diaryDate],
        orderBy: '${DiaryImagesTable.sortOrder} ASC',
      );

      final existingLocations = existingImageRows
          .map((row) => row[DiaryImagesTable.imageLocation] as String)
          .toSet();

      var nextOrder = existingImageRows.isEmpty
          ? 0
          : existingImageRows
                    .map((row) => row[DiaryImagesTable.sortOrder] as int)
                    .reduce((a, b) => a > b ? a : b) +
                1;

      // Add only new images, avoiding duplicates.
      for (final location in imageLocations) {
        if (existingLocations.add(location)) {
          await transaction.insert(DiaryImagesTable.name, {
            DiaryImagesTable.entryDate: diaryDate,
            DiaryImagesTable.imageLocation: location,
            DiaryImagesTable.sortOrder: nextOrder,
          });

          nextOrder++;
        }
      }

      // Remove the original draft only after the diary and images are saved.
      await transaction.delete(
        DiaryDraftsTable.name,
        where: '${DiaryDraftsTable.date} = ?',
        whereArgs: [date],
      );
    });
  }

  // Returns a draft for a particular date, or null if none exists.
  Future<DiaryDraftMap?> getDraft(String date) async {
    final database = await _appDatabase.database;

    final rows = await database.query(
      DiaryDraftsTable.name,
      where: '${DiaryDraftsTable.date} = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return _draftFromRow(rows.single);
  }

  // Returns all drafts, newest updated draft first.
  Future<List<DiaryDraftMap>> getAllDraftsNewestFirst() async {
    final database = await _appDatabase.database;

    final rows = await database.query(
      DiaryDraftsTable.name,
      orderBy: '${DiaryDraftsTable.updatedAt} DESC',
    );

    return rows.map(_draftFromRow).toList(growable: false);
  }

  // Returns drafts filtered by status.
  Future<List<DiaryDraftMap>> getDraftsByStatus(String status) async {
    if (status != DiaryDraftsTable.unfinished &&
        status != DiaryDraftsTable.unsaved) {
      throw ArgumentError.value(
        status,
        'status',
        'Must be unfinished or unsaved.',
      );
    }

    final database = await _appDatabase.database;

    final rows = await database.query(
      DiaryDraftsTable.name,
      where: '${DiaryDraftsTable.status} = ?',
      whereArgs: [status],
      orderBy: '${DiaryDraftsTable.updatedAt} DESC',
    );

    return rows.map(_draftFromRow).toList(growable: false);
  }

  // Deletes a draft after it has been successfully saved as a diary.
  Future<void> deleteDraft(String date) async {
    final database = await _appDatabase.database;

    await database.delete(
      DiaryDraftsTable.name,
      where: '${DiaryDraftsTable.date} = ?',
      whereArgs: [date],
    );
  }

  // Converts a database row into the public draft map.
  DiaryDraftMap _draftFromRow(Map<String, Object?> row) {
    final decodedImages = jsonDecode(
      row[DiaryDraftsTable.imagesData] as String,
    );

    if (decodedImages is! List) {
      throw const FormatException(
        'Invalid draft image data stored in the database.',
      );
    }

    final imageLocations = decodedImages
        .map((image) {
          if (image is! String) {
            throw const FormatException(
              'Invalid image reference stored in a diary draft.',
            );
          }
          return image;
        })
        .toList(growable: false);

    return {
      'date': row[DiaryDraftsTable.date],
      'title': row[DiaryDraftsTable.title],
      'text_data': row[DiaryDraftsTable.textData],
      'mood': row[DiaryDraftsTable.mood],
      'images_loc': imageLocations,
      'status': row[DiaryDraftsTable.status],
      'failure_reason': row[DiaryDraftsTable.failureReason],
      'created_at': row[DiaryDraftsTable.createdAt],
      'updated_at': row[DiaryDraftsTable.updatedAt],
    };
  }

  // Produces today's local date as the sortable YYYY-MM-DD database key.
  String _todayDateKey() {
    final today = DateTime.now();
    final year = today.year.toString().padLeft(4, '0');
    final month = today.month.toString().padLeft(2, '0');
    final day = today.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // Produces a UTC ISO-8601 timestamp.
  String _timestamp() => DateTime.now().toUtc().toIso8601String();
}
