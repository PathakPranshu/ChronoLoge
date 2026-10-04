import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/diary_entry_tile.dart';
import '../viewmodels/search_view_model.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchViewModelProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 20),
            SearchBar(
              hintText: 'Search date, title, text, or mood',
              leading: const Icon(Icons.search),
              onChanged: (text) =>
                  ref.read(searchViewModelProvider.notifier).search(text),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const Center(child: Text('Search could not be completed.')),
                data: (entries) => entries.isEmpty
                    ? const Center(child: Text('Search your diary entries.'))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) =>
                            DiaryEntryTile(entry: entries[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
