import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/diary_database.dart';
import '../../../core/utils/display_helpers.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../viewmodels/trash_view_model.dart';

/// Shows diary entries that can be restored for up to 30 days.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(trashViewModelProvider);
    final hasEntries = trash.value?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          IconButton(
            tooltip: 'Empty Trash',
            onPressed: hasEntries
                ? () => _confirmEmptyTrash(context, ref)
                : null,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(trashViewModelProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
        data: (entries) => entries.isEmpty
            ? const _EmptyTrashMessage()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const _TrashNotice(),
                  const SizedBox(height: 12),
                  for (final entry in entries)
                    _TrashEntryCard(
                      entry: entry,
                      onRestore: () => _restore(context, ref, entry),
                      onDelete: () =>
                          _confirmPermanentDelete(context, ref, entry),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TrashNotice extends StatelessWidget {
  const _TrashNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Entries in Trash are permanently deleted after 30 days.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashEntryCard extends StatelessWidget {
  const _TrashEntryCard({
    required this.entry,
    required this.onRestore,
    required this.onDelete,
  });

  final DiaryEntryMap entry;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = (entry['title'] as String? ?? '').trim();
    final text = (entry['text_data'] as String? ?? '').trim();
    final dateText = entry['date'] as String? ?? '';
    final date = DateTime.tryParse(dateText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled entry' : title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date == null ? dateText : formatFriendlyDate(date),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    _retentionLabel(entry['deleted_at'] as String?),
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Restore entry',
              onPressed: onRestore,
              icon: const Icon(Icons.restore_from_trash_outlined),
            ),
            IconButton(
              tooltip: 'Delete permanently',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ],
        ),
      ),
    );
  }

  String _retentionLabel(String? deletedAtText) {
    final deletedAt = DateTime.tryParse(deletedAtText ?? '')?.toLocal();
    if (deletedAt == null) return 'Deletes automatically within 30 days';
    final expiry = deletedAt.add(const Duration(days: 30));
    final seconds = expiry.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) return 'Scheduled for deletion';
    final days =
        (seconds + Duration.secondsPerDay - 1) ~/ Duration.secondsPerDay;
    return days == 1 ? 'Deletes in 1 day' : 'Deletes in $days days';
  }
}

class _EmptyTrashMessage extends StatelessWidget {
  const _EmptyTrashMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Trash is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Deleted diary entries will stay here for up to 30 days.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _restore(
  BuildContext context,
  WidgetRef ref,
  DiaryEntryMap entry,
) async {
  final date = entry['date'] as String?;
  if (date == null) return;
  final confirmed = await showConfirmationDialog(
    context,
    title: 'Restore entry?',
    message: 'This diary entry will return to Entries and Search.',
    confirmLabel: 'Restore',
    icon: Icons.restore_from_trash_outlined,
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(trashViewModelProvider.notifier).restore(date);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Diary entry restored.')));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not restore that entry.')),
    );
  }
}

Future<void> _confirmPermanentDelete(
  BuildContext context,
  WidgetRef ref,
  DiaryEntryMap entry,
) async {
  final confirmed = await showConfirmationDialog(
    context,
    title: 'Delete permanently?',
    message: 'This entry and its local media will be deleted forever. This cannot be undone.',
    confirmLabel: 'Delete',
    icon: Icons.delete_forever_outlined,
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final date = entry['date'] as String?;
  if (date == null) return;
  try {
    await ref.read(trashViewModelProvider.notifier).permanentlyDelete(date);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not permanently delete that entry.')),
    );
  }
}

Future<void> _confirmEmptyTrash(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmationDialog(
    context,
    title: 'Empty Trash?',
    message:
        'Every entry in Trash and its local media will be deleted forever.',
    confirmLabel: 'Empty Trash',
    icon: Icons.delete_sweep_outlined,
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(trashViewModelProvider.notifier).emptyTrash();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not empty Trash.')));
  }
}
