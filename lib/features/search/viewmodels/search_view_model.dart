import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/diary_database.dart';

final searchViewModelProvider =
    AsyncNotifierProvider<SearchViewModel, List<DiaryEntryMap>>(
      SearchViewModel.new,
    );

class SearchViewModel extends AsyncNotifier<List<DiaryEntryMap>> {
  int _requestId = 0;

  @override
  Future<List<DiaryEntryMap>> build() async => [];

  Future<void> search(String text) async {
    final requestId = ++_requestId;
    final query = text.trim();
    if (query.isEmpty) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(diaryDatabaseProvider).searchDiary(query),
    );
    if (requestId == _requestId) state = result;
  }
}
