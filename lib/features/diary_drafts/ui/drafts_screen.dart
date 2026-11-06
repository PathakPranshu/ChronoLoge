import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/routing/routes.dart';
import '../shared/providers/diary_drafts_provider.dart';

class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  static const _testDate = '2099-01-01';
  static const _sampleDate = '2099-01-02';

  Future<void> _runDatabaseTest(BuildContext context, WidgetRef ref) async {
    final database = ref.read(diaryDraftDatabaseProvider);

    try {
      await database.deleteDraft(_testDate);
      await database.deleteDraft(_sampleDate);

      // Test 1: Save and retrieve an unfinished draft.
      await database.saveDraft(
        date: _testDate,
        title: 'Database test',
        textData: 'Initial draft content',
        status: DiaryDraftsTable.unfinished,
      );

      final firstDraft = await database.getDraft(_testDate);

      if (firstDraft == null ||
          firstDraft['status'] != DiaryDraftsTable.unfinished) {
        throw StateError('Save or retrieval test failed.');
      }

      final originalCreatedAt = firstDraft['created_at'];

      // Test 2: Update the same draft as an unsaved diary.
      await database.saveDraft(
        date: _testDate,
        title: 'Updated database test',
        textData: 'Updated draft content',
        status: DiaryDraftsTable.unsaved,
        failureReason: 'Test internet failure',
      );

      final updatedDraft = await database.getDraft(_testDate);

      if (updatedDraft == null ||
          updatedDraft['title'] != 'Updated database test' ||
          updatedDraft['status'] != DiaryDraftsTable.unsaved ||
          updatedDraft['created_at'] != originalCreatedAt ||
          updatedDraft['failure_reason'] != 'Test internet failure') {
        throw StateError('Draft update test failed.');
      }

      // Test 3: Delete the test draft.
      await database.deleteDraft(_testDate);

      final deletedDraft = await database.getDraft(_testDate);

      if (deletedDraft != null) {
        throw StateError('Draft deletion test failed.');
      }

      // Create a separate sample that can be seen on the screen.
      await database.saveDraft(
        date: _sampleDate,
        title: 'Sample unsaved diary',
        textData: 'This is a sample draft created for testing ChronoLoge.',
        mood: 'Happy',
        status: DiaryDraftsTable.unsaved,
        failureReason: 'Sample: internet connection unavailable.',
      );

      final sample = await database.getDraft(_sampleDate);

      if (sample == null || sample['status'] != DiaryDraftsTable.unsaved) {
        throw StateError('Sample draft verification failed.');
      }

      ref.invalidate(diaryDraftsProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database tests passed! Sample draft created.'),
        ),
      );
    } catch (error) {
      ref.invalidate(diaryDraftsProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database test failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _removeTestDraft(BuildContext context, WidgetRef ref) async {
    try {
      final database = ref.read(diaryDraftDatabaseProvider);

      await database.deleteDraft(_testDate);
      await database.deleteDraft(_sampleDate);

      ref.invalidate(diaryDraftsProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Test drafts removed.')));
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cleanup failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsState = ref.watch(diaryDraftsProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drafts'),
        actions: [
          if (kDebugMode) ...[
            IconButton(
              tooltip: 'Run database test',
              icon: const Icon(Icons.science_outlined),
              onPressed: () => _runDatabaseTest(context, ref),
            ),
            IconButton(
              tooltip: 'Remove test drafts',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () => _removeTestDraft(context, ref),
            ),
          ],
          IconButton(
            tooltip: 'Refresh drafts',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(diaryDraftsProvider),
          ),
        ],
      ),
      body: draftsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text('Unable to load drafts.'),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(diaryDraftsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (drafts) {
          if (drafts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.drafts_outlined,
                      size: 64,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No drafts yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unfinished or unsaved diaries will appear here.',
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
            itemCount: drafts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final draft = drafts[index];

              final date = draft['date'] as String? ?? '';
              final title = draft['title'] as String? ?? '';
              final textData = draft['text_data'] as String? ?? '';
              final status = draft['status'] as String? ?? '';
              final failureReason = draft['failure_reason'] as String?;
              final images = draft['images_loc'] as List<String>? ?? [];

              final isUnfinished = status == DiaryDraftsTable.unfinished;
              final statusLabel = isUnfinished ? 'Unfinished' : 'Unsaved';

              final displayTitle = title.trim().isNotEmpty
                  ? title.trim()
                  : 'Untitled diary';

              final preview = textData.trim().isNotEmpty
                  ? textData.trim()
                  : 'No diary text available';

              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    context.push(
                      '${Routes.draftEditor}?date=${Uri.encodeComponent(date)}',
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isUnfinished
                                  ? Icons.edit_note
                                  : Icons.cloud_off_outlined,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusLabel,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Text(
                              date,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        if (images.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.image_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${images.length} image${images.length == 1 ? '' : 's'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                        if (failureReason != null &&
                            failureReason.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Reason: $failureReason',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.error),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              context.push(
                                '${Routes.draftEditor}?date=${Uri.encodeComponent(date)}',
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Draft'),
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
