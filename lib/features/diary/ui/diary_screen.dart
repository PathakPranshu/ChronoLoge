import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/providers/diary_entries_provider.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  String _formatDate(String date) {
    final parts = date.split('-');

    if (parts.length != 3) return date;

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

    final month = int.tryParse(parts[1]);

    if (month == null || month < 1 || month > 12) return date;

    return '${parts[2]} ${months[month - 1]} ${parts[0]}';
  }

  void _showDiary(BuildContext context, Map<String, Object?> entry) {
    final date = entry['date'] as String? ?? '';
    final title = (entry['title'] as String? ?? '').trim();
    final textData = (entry['text_data'] as String? ?? '').trim();
    final mood = (entry['mood'] as String? ?? '').trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(date),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title.isNotEmpty ? title : 'Untitled diary',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (mood.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.mood_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(mood),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    SelectableText(
                      textData.isNotEmpty
                          ? textData
                          : 'No diary text available.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(height: 1.7),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesState = ref.watch(diaryEntriesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Diary'),
        actions: [
          IconButton(
            tooltip: 'Refresh diaries',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(diaryEntriesProvider),
          ),
        ],
      ),
      body: entriesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text('Unable to load diaries.'),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(diaryEntriesProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your diary is empty',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Diaries you save will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];

              final date = entry['date'] as String? ?? '';
              final title = (entry['title'] as String? ?? '').trim();
              final textData = (entry['text_data'] as String? ?? '').trim();
              final mood = (entry['mood'] as String? ?? '').trim();
              final images = entry['images_loc'] as List<String>? ?? [];

              final preview = textData.isNotEmpty
                  ? textData
                  : 'No diary text available.';

              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showDiary(context, entry),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatDate(date),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: colors.primary),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title.isNotEmpty ? title : 'Untitled diary',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        if (mood.isNotEmpty || images.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              if (mood.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.mood_outlined, size: 17),
                                    const SizedBox(width: 5),
                                    Text(mood),
                                  ],
                                ),
                              if (images.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_outlined, size: 17),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${images.length} image${images.length == 1 ? '' : 's'}',
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Read diary',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: colors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
