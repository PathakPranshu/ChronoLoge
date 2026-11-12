import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/display_helpers.dart';
import '../../../core/widgets/encrypted_media_image.dart';
import '../../../core/widgets/mood_picker.dart';
import '../../../core/widgets/voice_memo_player.dart';
import '../../today/views/voice_memo_dialog.dart';
import '../viewmodels/diary_entry_view_model.dart';

/// Edits the manual summary for one date.
///
/// It can be shown alone for an empty date or embedded in DiaryViewPage.
class DiaryEntryPage extends ConsumerStatefulWidget {
  const DiaryEntryPage({required this.date, this.embedded = false, super.key});

  final DateTime date;
  final bool embedded;

  @override
  ConsumerState<DiaryEntryPage> createState() => _DiaryEntryPageState();
}

class _DiaryEntryPageState extends ConsumerState<DiaryEntryPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  bool _initializedControllers = false;

  String get _dateKey => formatDateKey(widget.date);

  String get _dateLabel => formatFriendlyDate(widget.date);

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(diaryEntryViewModelProvider(_dateKey));
    final entryValue = entry.value;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                entryValue?.dateLabel ?? _dateLabel,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.normal),
              ),
            ),
      body: SafeArea(
        top: false,
        child: entry.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _EntryError(
            onRetry: () =>
                ref.invalidate(diaryEntryViewModelProvider(_dateKey)),
          ),
          data: (entry) {
            if (!_initializedControllers) {
              _titleController.text = entry.title;
              _textController.text = entry.text;
              _initializedControllers = true;
            }
            return _EntryEditor(
              entry: entry,
              titleController: _titleController,
              textController: _textController,
              onMoodSelected: (mood) => ref
                  .read(diaryEntryViewModelProvider(_dateKey).notifier)
                  .setMood(mood),
              onPickImages: _pickImages,
              onRecordVoiceMemo: () => _recordVoiceMemo(entry),
            );
          },
        ),
      ),
      bottomNavigationBar: entryValue == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  height: 72,
                  child: Center(
                    child: IconButton.filled(
                      tooltip: 'Save entry',
                      onPressed: entryValue.isSaving ? null : _save,
                      iconSize: 32,
                      padding: const EdgeInsets.all(18),
                      icon: entryValue.isSaving
                          ? const SizedBox.square(
                              dimension: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Icon(Icons.save_rounded),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _pickImages() async {
    try {
      await ref
          .read(diaryEntryViewModelProvider(_dateKey).notifier)
          .pickImages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add those images.')),
      );
    }
  }

  Future<void> _recordVoiceMemo(DiaryEntryState entry) async {
    try {
      final memoPath = await showVoiceMemoDialog(
        context,
        dateKey: entry.dateKey,
      );
      if (memoPath == null || !mounted) return;
      await ref
          .read(diaryEntryViewModelProvider(_dateKey).notifier)
          .addVoiceMemoDraft(memoPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that voice memo.')),
      );
    }
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await ref
          .read(diaryEntryViewModelProvider(_dateKey).notifier)
          .save(title: _titleController.text, text: _textController.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this diary entry.')),
      );
    }
  }
}

class _EntryEditor extends StatelessWidget {
  const _EntryEditor({
    required this.entry,
    required this.titleController,
    required this.textController,
    required this.onMoodSelected,
    required this.onPickImages,
    required this.onRecordVoiceMemo,
  });

  final DiaryEntryState entry;
  final TextEditingController titleController;
  final TextEditingController textController;
  final ValueChanged<String> onMoodSelected;
  final VoidCallback onPickImages;
  final VoidCallback onRecordVoiceMemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        TextField(
          controller: titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Title'),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: textController,
          minLines: 9,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Write about this day...',
            filled: true,
            fillColor: colors.surfaceContainerLow,
            contentPadding: const EdgeInsets.all(20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            MoodPicker(selectedMood: entry.mood, onSelected: onMoodSelected),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Record voice memo',
              onPressed: entry.isAddingMedia ? null : onRecordVoiceMemo,
              icon: Icon(Icons.mic_none_rounded, color: colors.primary),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Add images',
              onPressed: entry.isAddingMedia ? null : onPickImages,
              icon: entry.isAddingMedia
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Icon(
                      Icons.add_photo_alternate_outlined,
                      color: colors.primary,
                    ),
            ),
          ],
        ),
        if (entry.voiceMemoLocations.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Voice memos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (
            var index = 0;
            index < entry.voiceMemoLocations.length;
            index++
          ) ...[
            VoiceMemoPlayer(
              audioLocation: entry.voiceMemoLocations[index],
              memoNumber: index + 1,
            ),
            if (index != entry.voiceMemoLocations.length - 1)
              const SizedBox(height: 8),
          ],
        ],
        if (entry.imageLocations.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Photos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entry.imageLocations.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 250,
                  child: EncryptedMediaImage(
                    filePath: entry.imageLocations[index],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EntryError extends StatelessWidget {
  const _EntryError({required this.onRetry});

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
