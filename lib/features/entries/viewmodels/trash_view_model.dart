import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/diary_database.dart';
import '../../../core/services/diagnostic_log_service.dart';
import '../../../core/utils/file_helpers.dart';
import '../../search/viewmodels/search_view_model.dart';
import 'entries_view_model.dart';

final trashViewModelProvider =
    AsyncNotifierProvider<TrashViewModel, List<DiaryEntryMap>>(
      TrashViewModel.new,
    );

/// Runs the 30-day cleanup even when the Trash page is never opened.
final trashMaintenanceProvider = FutureProvider<void>((ref) async {
  final files = await ref.read(diaryDatabaseProvider).deleteExpiredTrash();
  await deleteFilesIfPresent(files);
  if (files.isNotEmpty) {
    await DiagnosticLogService.record(
      'trash',
      'Expired trash was removed, including ${files.length} media files',
    );
  }
});

/// Loads deleted entries and handles restore or permanent deletion actions.
class TrashViewModel extends AsyncNotifier<List<DiaryEntryMap>> {
  @override
  Future<List<DiaryEntryMap>> build() async {
    final database = ref.read(diaryDatabaseProvider);
    final expiredFiles = await database.deleteExpiredTrash();
    await deleteFilesIfPresent(expiredFiles);
    return database.getTrashedEntriesNewestFirst();
  }

  // Moves an entry out of Trash and back into the main diary.
  Future<void> restore(String date) async {
    await ref.read(diaryDatabaseProvider).restoreEntry(date);
    _refreshDiaryPages();
    await _reload();
  }

  // Deletes one trashed entry and all of its local media forever.
  Future<void> permanentlyDelete(String date) async {
    final files = await ref
        .read(diaryDatabaseProvider)
        .permanentlyDeleteEntry(date);
    await deleteFilesIfPresent(files);
    _refreshDiaryPages();
    await _reload();
  }

  // Deletes every entry and media file currently in Trash.
  Future<void> emptyTrash() async {
    final files = await ref.read(diaryDatabaseProvider).emptyTrash();
    await deleteFilesIfPresent(files);
    _refreshDiaryPages();
    await _reload();
  }

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(diaryDatabaseProvider).getTrashedEntriesNewestFirst(),
    );
  }

  void _refreshDiaryPages() {
    ref.invalidate(entriesViewModelProvider);
    ref.invalidate(searchViewModelProvider);
  }
}
