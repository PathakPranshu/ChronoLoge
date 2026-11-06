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

  // Produces a UTC ISO-8601 timestamp.
  String _timestamp() => DateTime.now().toUtc().toIso8601String();
}
