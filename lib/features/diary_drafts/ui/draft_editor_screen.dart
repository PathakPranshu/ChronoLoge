import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_providers.dart';
import '../shared/providers/diary_drafts_provider.dart';

class DraftEditorScreen extends ConsumerStatefulWidget {
  const DraftEditorScreen({required this.date, super.key});

  final String date;

  @override
  ConsumerState<DraftEditorScreen> createState() => _DraftEditorScreenState();
}

class _DraftEditorScreenState extends ConsumerState<DraftEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _moodController = TextEditingController();

  late Future<Map<String, Object?>?> _draftFuture;

  String _status = DiaryDraftsTable.unfinished;
  String? _failureReason;
  List<String> _imageLocations = [];

  bool _isSaving = false;
  bool _controllersInitialized = false;

  static const Color _inputTextColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _draftFuture = _loadDraft();
  }

  Future<Map<String, Object?>?> _loadDraft() {
    return ref.read(diaryDraftDatabaseProvider).getDraft(widget.date);
  }

  void _initializeControllers(Map<String, Object?> draft) {
    if (_controllersInitialized) return;

    _titleController.text = draft['title'] as String? ?? '';
    _textController.text = draft['text_data'] as String? ?? '';
    _moodController.text = draft['mood'] as String? ?? '';

    _status = draft['status'] as String? ?? DiaryDraftsTable.unfinished;
    _failureReason = draft['failure_reason'] as String?;

    _imageLocations = draft['images_loc'] as List<String>? ?? [];

    _controllersInitialized = true;
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final database = ref.read(diaryDraftDatabaseProvider);

      await database.saveDraft(
        date: widget.date,
        title: _titleController.text.trim(),
        textData: _textController.text.trim(),
        mood: _moodController.text.trim(),
        status: _status,
        imageLocations: _imageLocations,
        failureReason: _failureReason,
      );

      ref.invalidate(diaryDraftsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved successfully.')),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save draft: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAsDiary() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final database = ref.read(diaryDraftDatabaseProvider);

      await database.saveDraftAsDiary(
        date: widget.date,
        title: _titleController.text.trim(),
        textData: _textController.text.trim(),
        mood: _moodController.text.trim(),
        imageLocations: _imageLocations,
      );

      ref.invalidate(diaryDraftsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diary saved successfully. Draft completed.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save diary: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _moodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Draft')),
      body: FutureBuilder<Map<String, Object?>?>(
        future: _draftFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load draft: ${snapshot.error}'),
            );
          }

          final draft = snapshot.data;

          if (draft == null) {
            return const Center(child: Text('This draft could not be found.'));
          }

          _initializeControllers(draft);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.date,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: _inputTextColor),
                  cursorColor: _inputTextColor,
                  decoration: const InputDecoration(
                    labelText: 'Diary title',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _textController,
                  style: const TextStyle(color: _inputTextColor),
                  cursorColor: _inputTextColor,
                  decoration: const InputDecoration(
                    labelText: 'Diary content',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  minLines: 8,
                  maxLines: 16,
                  validator: (value) {
                    if (_titleController.text.trim().isEmpty &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Add a title or some diary content.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _moodController,
                  style: const TextStyle(color: _inputTextColor),
                  cursorColor: _inputTextColor,
                  decoration: const InputDecoration(
                    labelText: 'Mood',
                    hintText: 'e.g. Happy, Calm, Excited',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Draft type',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _status,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      selectedItemBuilder: (context) {
                        return const [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Unfinished',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Unsaved',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ];
                      },
                      items: const [
                        DropdownMenuItem(
                          value: DiaryDraftsTable.unfinished,
                          child: Text(
                            'Unfinished',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                        DropdownMenuItem(
                          value: DiaryDraftsTable.unsaved,
                          child: Text(
                            'Unsaved',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
                    ),
                  ),
                ),

                if (_imageLocations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${_imageLocations.length} attached image(s) '
                    'will be preserved.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],

                if (_failureReason != null &&
                    _failureReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Previous failure: $_failureReason',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveDraft,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save changes'),
                ),

                const SizedBox(height: 12),

                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveAsDiary,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.menu_book_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save as Diary'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
