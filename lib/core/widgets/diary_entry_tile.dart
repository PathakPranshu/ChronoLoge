import 'package:flutter/material.dart';

import '../database/diary_database.dart';

class DiaryEntryTile extends StatelessWidget {
  const DiaryEntryTile({required this.entry, this.onTap, super.key});

  final DiaryEntryMap entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = entry['title'] as String? ?? '';
    final text = entry['text_data'] as String? ?? '';
    final mood = entry['mood'] as String? ?? '';
    final date = entry['date'] as String? ?? '';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(title.isEmpty ? 'Untitled entry' : title),
        subtitle: Text(
          [
            date,
            if (text.isNotEmpty) text,
            if (mood.isNotEmpty) mood,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
