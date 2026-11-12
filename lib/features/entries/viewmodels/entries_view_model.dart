import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/diary_database.dart';

final entriesViewModelProvider =
    AsyncNotifierProvider<EntriesViewModel, EntriesState>(EntriesViewModel.new);

/// Calendar and list data used by the Entries page.
class EntriesState {
  const EntriesState({
    required this.visibleMonth,
    required this.monthDays,
    required this.entries,
  });

  final DateTime visibleMonth;
  final List<DiaryEntryMap> monthDays;
  final List<DiaryEntryMap> entries;

  EntriesState copyWith({
    DateTime? visibleMonth,
    List<DiaryEntryMap>? monthDays,
    List<DiaryEntryMap>? entries,
  }) {
    return EntriesState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      monthDays: monthDays ?? this.monthDays,
      entries: entries ?? this.entries,
    );
  }
}

/// Loads diary dates and moves the calendar between months.
class EntriesViewModel extends AsyncNotifier<EntriesState> {
  int _monthRequestId = 0;

  @override
  Future<EntriesState> build() {
    final now = DateTime.now();
    return _load(DateTime(now.year, now.month));
  }

  Future<void> showPreviousMonth() {
    final month = state.requireValue.visibleMonth;
    return _showMonth(DateTime(month.year, month.month - 1));
  }

  Future<void> showNextMonth() {
    final month = state.requireValue.visibleMonth;
    return _showMonth(DateTime(month.year, month.month + 1));
  }

  Future<void> showCurrentMonth() {
    final now = DateTime.now();
    return _showMonth(DateTime(now.year, now.month));
  }

  Future<void> refresh() async {
    final month = state.value?.visibleMonth ?? DateTime.now();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _load(DateTime(month.year, month.month)),
    );
  }

  Future<void> _showMonth(DateTime month) async {
    final requestId = ++_monthRequestId;
    final current = state.requireValue;
    final days = await ref
        .read(diaryDatabaseProvider)
        .getMonthData(month.year, month.month);
    if (requestId != _monthRequestId) return;
    state = AsyncData(current.copyWith(visibleMonth: month, monthDays: days));
  }

  Future<EntriesState> _load(DateTime month) async {
    final database = ref.read(diaryDatabaseProvider);
    final monthDaysFuture = database.getMonthData(month.year, month.month);
    final entriesFuture = database.getAllEntriesNewestFirst();

    return EntriesState(
      visibleMonth: month,
      monthDays: await monthDaysFuture,
      entries: await entriesFuture,
    );
  }
}
