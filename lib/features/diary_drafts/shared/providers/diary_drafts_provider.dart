import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/database/diary_draft_database.dart';

final diaryDraftsProvider = FutureProvider<List<DiaryDraftMap>>((ref) {
  return ref.watch(diaryDraftDatabaseProvider).getAllDraftsNewestFirst();
});
