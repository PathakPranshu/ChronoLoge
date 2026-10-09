import 'package:flutter/material.dart';

/// A small popup that lets the user choose one of the supported moods.
class MoodPicker extends StatefulWidget {
  const MoodPicker({
    required this.selectedMood,
    required this.onSelected,
    super.key,
  });

  final String selectedMood;
  final ValueChanged<String> onSelected;

  @override
  State<MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends State<MoodPicker> {
  // The name is saved in SQLite. The emoji is only used for display.
  static const moods = [
    ('Great', '😄'),
    ('Happy', '😊'),
    ('Calm', '😌'),
    ('Tired', '😴'),
    ('Sad', '😔'),
    ('Stressed', '😣'),
  ];

  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final selectedEmoji = _findSelectedEmoji();
    final colors = Theme.of(context).colorScheme;

    return MenuAnchor(
      controller: _menu,
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
                for (final mood in moods)
                  Tooltip(
                    message: mood.$1,
                    child: Semantics(
                      label: mood.$1,
                      selected: widget.selectedMood == mood.$1,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _chooseMood(mood.$1),
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
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => IconButton.filledTonal(
        tooltip: 'Choose mood',
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: Text(selectedEmoji ?? '🙂', style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  String? _findSelectedEmoji() {
    for (final mood in moods) {
      if (mood.$1 == widget.selectedMood) return mood.$2;
    }
    return null;
  }

  void _chooseMood(String mood) {
    widget.onSelected(mood);
    _menu.close();
  }
}
