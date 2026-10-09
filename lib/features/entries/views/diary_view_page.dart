import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/display_helpers.dart';
import '../../../core/widgets/encrypted_media_image.dart';
import '../../../core/widgets/voice_memo_player.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/viewmodels/settings_view_model.dart';
import '../viewmodels/diary_view_model.dart';
import 'diary_entry_page.dart';

/// Shows a saved day using separate Timeline and Summary tabs.
class DiaryViewPage extends ConsumerWidget {
  const DiaryViewPage({required this.date, super.key});

  final DateTime date;

  String get _dateKey => formatDateKey(date);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            formatFriendlyDate(date),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.normal),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.timeline_rounded), text: 'Timeline'),
              Tab(icon: Icon(Icons.notes_rounded), text: 'Summary'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DiaryTimeline(dateKey: _dateKey),
            DiaryEntryPage(date: date, embedded: true),
          ],
        ),
      ),
    );
  }
}

class _DiaryTimeline extends ConsumerWidget {
  const _DiaryTimeline({required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(diaryViewModelProvider(dateKey));
    final timeFormat =
        ref.watch(settingsViewModelProvider).value?.timeFormat ??
        TimeFormat.hour24;

    return timeline.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: FilledButton.tonalIcon(
          onPressed: () => ref.invalidate(diaryViewModelProvider(dateKey)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ),
      data: (state) {
        if (state.timelineItems.isEmpty) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(diaryViewModelProvider(dateKey).notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 160),
                Icon(Icons.timeline_rounded, size: 42),
                SizedBox(height: 12),
                Text(
                  'No timeline data was collected for this day.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(diaryViewModelProvider(dateKey).notifier).refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemCount: state.timelineItems.length,
            itemBuilder: (context, index) => _TimelineItemCard(
              item: state.timelineItems[index],
              timeFormat: timeFormat,
              isLast: index == state.timelineItems.length - 1,
            ),
          ),
        );
      },
    );
  }
}

class _TimelineItemCard extends StatelessWidget {
  const _TimelineItemCard({
    required this.item,
    required this.timeFormat,
    required this.isLast,
  });

  final DiaryTimelineItem item;
  final TimeFormat timeFormat;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emoji = moodEmoji(item.mood);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              formatClockTime(
                item.occurredAt,
                use24Hour: timeFormat == TimeFormat.hour24,
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(child: VerticalDivider(color: colors.outlineVariant)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.locationLabel.isNotEmpty ||
                          item.weatherLabel.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (item.locationLabel.isNotEmpty)
                              _ContextPill(
                                icon: Icons.location_on_outlined,
                                label: item.locationLabel,
                              ),
                            if (item.weatherLabel.isNotEmpty)
                              _ContextPill(
                                icon: Icons.cloud_outlined,
                                label: item.weatherLabel,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (item.text.isNotEmpty)
                        Text(
                          item.text,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      if (emoji != null) ...[
                        if (item.text.isNotEmpty) const SizedBox(height: 8),
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                      ],
                      if (item.imageLocations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 104,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.imageLocations.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) => ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 140,
                                child: EncryptedMediaImage(
                                  filePath: item.imageLocations[index],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (item.voiceMemoLocations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (
                          var index = 0;
                          index < item.voiceMemoLocations.length;
                          index++
                        ) ...[
                          VoiceMemoPlayer(
                            audioLocation: item.voiceMemoLocations[index],
                            memoNumber: index + 1,
                          ),
                          if (index != item.voiceMemoLocations.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}
