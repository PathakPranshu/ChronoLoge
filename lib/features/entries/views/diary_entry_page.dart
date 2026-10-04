import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../today/views/voice_memo_dialog.dart';
import '../viewmodels/diary_entry_view_model.dart';

class DiaryEntryPage extends ConsumerStatefulWidget {
  const DiaryEntryPage({required this.date, super.key});

  final DateTime date;

  @override
  ConsumerState<DiaryEntryPage> createState() => _DiaryEntryPageState();
}

class _DiaryEntryPageState extends ConsumerState<DiaryEntryPage> {
  static const _months = [
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

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  bool _initializedControllers = false;

  String get _dateKey {
    final year = widget.date.year.toString().padLeft(4, '0');
    final month = widget.date.month.toString().padLeft(2, '0');
    final day = widget.date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String get _dateLabel {
    final day = widget.date.day;
    final suffix = day >= 11 && day <= 13
        ? 'th'
        : switch (day % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$day$suffix ${_months[widget.date.month - 1]} ${widget.date.year}';
  }

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
      appBar: AppBar(
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
            );
          },
        ),
      ),
      floatingActionButton: entryValue == null
          ? null
          : FloatingActionButton.extended(
              onPressed: entryValue.isAddingMedia
                  ? null
                  : () => _showAddMedia(entryValue),
              icon: entryValue.isAddingMedia
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(entryValue.isAddingMedia ? 'Adding...' : 'Add'),
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

  Future<void> _showAddMedia(DiaryEntryState entry) async {
    final action = await showModalBottomSheet<_EntryMediaAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('Add images'),
                onTap: () => Navigator.pop(context, _EntryMediaAction.images),
              ),
              ListTile(
                leading: const Icon(Icons.mic_none_rounded),
                title: const Text('Record voice memo'),
                onTap: () =>
                    Navigator.pop(context, _EntryMediaAction.voiceMemo),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;

    try {
      switch (action) {
        case _EntryMediaAction.images:
          await ref
              .read(diaryEntryViewModelProvider(_dateKey).notifier)
              .pickImages();
          return;
        case _EntryMediaAction.voiceMemo:
          final memoPath = await showVoiceMemoDialog(
            context,
            dateKey: entry.dateKey,
          );
          if (memoPath != null && mounted) {
            ref
                .read(diaryEntryViewModelProvider(_dateKey).notifier)
                .addVoiceMemoDraft(memoPath);
          }
          return;
        case null:
          return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that media.')),
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

enum _EntryMediaAction { images, voiceMemo }

class _EntryEditor extends StatelessWidget {
  const _EntryEditor({
    required this.entry,
    required this.titleController,
    required this.textController,
    required this.onMoodSelected,
  });

  final DiaryEntryState entry;
  final TextEditingController titleController;
  final TextEditingController textController;
  final ValueChanged<String> onMoodSelected;

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
            Expanded(
              child: Text(
                'Mood',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _EntryMoodPicker(
              selectedMood: entry.mood,
              onSelected: onMoodSelected,
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
            _EntryVoiceMemo(
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
                  child: Image.file(
                    File(entry.imageLocations[index]),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
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

class _EntryMoodPicker extends StatefulWidget {
  const _EntryMoodPicker({
    required this.selectedMood,
    required this.onSelected,
  });

  final String selectedMood;
  final ValueChanged<String> onSelected;

  @override
  State<_EntryMoodPicker> createState() => _EntryMoodPickerState();
}

class _EntryMoodPickerState extends State<_EntryMoodPicker> {
  static const _moods = [
    ('Great', '😄'),
    ('Happy', '😊'),
    ('Calm', '😌'),
    ('Tired', '😴'),
    ('Sad', '😔'),
    ('Stressed', '😣'),
  ];

  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final selectedEmoji = _moods
        .where((mood) => mood.$1 == widget.selectedMood)
        .map((mood) => mood.$2)
        .firstOrNull;
    final colors = Theme.of(context).colorScheme;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-144, 6),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 168,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final mood in _moods)
                  Tooltip(
                    message: mood.$1,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        widget.onSelected(mood.$1);
                        _menuController.close();
                      },
                      child: Container(
                        width: 48,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.selectedMood == mood.$1
                              ? colors.secondaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          mood.$2,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => IconButton.filledTonal(
        tooltip: 'Choose mood',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Text(selectedEmoji ?? '🙂', style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _EntryVoiceMemo extends StatefulWidget {
  const _EntryVoiceMemo({
    required this.audioLocation,
    required this.memoNumber,
  });

  final String audioLocation;
  final int memoNumber;

  @override
  State<_EntryVoiceMemo> createState() => _EntryVoiceMemoState();
}

class _EntryVoiceMemoState extends State<_EntryVoiceMemo> {
  final AudioPlayer _player = AudioPlayer();
  bool _isLoaded = false;

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data?.playing ?? false;
          return ListTile(
            leading: IconButton.filledTonal(
              tooltip: isPlaying ? 'Pause' : 'Play',
              onPressed: _togglePlayback,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            title: Text('Voice memo ${widget.memoNumber}'),
          );
        },
      ),
    );
  }

  Future<void> _togglePlayback() async {
    if (!_isLoaded) {
      await _player.setFilePath(widget.audioLocation);
      _isLoaded = true;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play());
    }
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
