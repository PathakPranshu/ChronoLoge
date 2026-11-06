import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/database/diary_database.dart';

final diaryEntriesProvider = FutureProvider<List<DiaryEntryMap>>((ref) {
  return ref.watch(diaryDatabaseProvider).getAllEntriesNewestFirst();
});
