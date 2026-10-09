import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/diary_database.dart';
import '../../../core/widgets/diary_entry_tile.dart';
import '../viewmodels/entries_view_model.dart';
import 'diary_entry_page.dart';
import 'diary_view_page.dart';

/// Lets the user find diary days using a calendar or newest-first list.
class EntriesPage extends ConsumerWidget {
  const EntriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesViewModelProvider);

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Entries',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 14),
              const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.calendar_month_outlined),
                    text: 'Calendar',
                  ),
                  Tab(icon: Icon(Icons.view_list_outlined), text: 'List'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: entries.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _EntriesError(
                    onRetry: () =>
                        ref.read(entriesViewModelProvider.notifier).refresh(),
                  ),
                  data: (entries) => TabBarView(
                    children: [
                      _CalendarView(entries: entries),
                      _EntriesList(entries: entries.entries),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarView extends ConsumerWidget {
  const _CalendarView({required this.entries});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final EntriesState entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = entries.visibleMonth;
    final firstDay = DateTime(month.year, month.month);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmptyDays = firstDay.weekday - 1;
    final cellCount = ((leadingEmptyDays + dayCount + 6) ~/ 7) * 7;

    return RefreshIndicator(
      onRefresh: () => ref.read(entriesViewModelProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => ref
                    .read(entriesViewModelProvider.notifier)
                    .showPreviousMonth(),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => ref
                      .read(entriesViewModelProvider.notifier)
                      .showCurrentMonth(),
                  child: Text(
                    _monthLabel(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () =>
                    ref.read(entriesViewModelProvider.notifier).showNextMonth(),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.9,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final day = index - leadingEmptyDays + 1;
              if (day < 1 || day > dayCount) return const SizedBox.shrink();

              final dayData = entries.monthDays[day - 1];
              final entry = dayData['entry'] as DiaryEntryMap?;
              return _CalendarDay(
                day: day,
                hasEntry: entry != null,
                isToday: _isToday(month.year, month.month, day),
                onTap: () => _openDiaryEntry(
                  context,
                  ref,
                  DateTime(month.year, month.month, day),
                  hasData: entry != null,
                ),
              );
            },
          ),
          if (entries.monthDays.every((day) => day['entry'] == null)) ...[
            const SizedBox(height: 20),
            Text(
              'No diary entries this month yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _monthLabel(DateTime month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  bool _isToday(int year, int month, int day) {
    final today = DateTime.now();
    return today.year == year && today.month == month && today.day == day;
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.hasEntry,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool hasEntry;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: isToday
                  ? colors.primaryContainer
                  : hasEntry
                  ? colors.surfaceContainerHigh
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isToday ? Border.all(color: colors.primary) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isToday || hasEntry
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 5,
                  height: 5,
                  child: hasEntry
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntriesList extends ConsumerWidget {
  const _EntriesList({required this.entries});

  final List<DiaryEntryMap> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(entriesViewModelProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.menu_book_outlined, size: 42),
            SizedBox(height: 12),
            Text(
              'Your diary entries will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(entriesViewModelProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final date = DateTime.tryParse(entry['date'] as String? ?? '');
          return DiaryEntryTile(
            entry: entry,
            onTap: date == null
                ? null
                : () => _openDiaryEntry(context, ref, date, hasData: true),
          );
        },
      ),
    );
  }
}

Future<void> _openDiaryEntry(
  BuildContext context,
  WidgetRef ref,
  DateTime date, {
  required bool hasData,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (context) =>
          hasData ? DiaryViewPage(date: date) : DiaryEntryPage(date: date),
    ),
  );
  if (saved == true) {
    await ref.read(entriesViewModelProvider.notifier).refresh();
  }
}

class _EntriesError extends StatelessWidget {
  const _EntriesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try again'),
      ),
    );
  }
}
