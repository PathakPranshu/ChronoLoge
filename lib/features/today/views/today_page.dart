import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/media_constants.dart';
import '../../../core/utils/display_helpers.dart';
import '../../../core/utils/file_helpers.dart';
import '../../../core/widgets/encrypted_media_image.dart';
import '../../../core/widgets/mood_picker.dart';
import '../../../core/widgets/voice_memo_player.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/viewmodels/settings_view_model.dart';
import '../viewmodels/today_view_model.dart';
import 'voice_memo_dialog.dart';

/// The main diary page for the current day.
///
/// Automatic mode shows the timeline and map. Manual mode shows the editable
/// summary. All saving work is passed to TodayViewModel.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  Timer? _autoSaveTimer;
  String? _loadedDate;
  String? _pendingTitle;
  String? _pendingText;
  bool _saveInProgress = false;

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    final pendingTitle = _pendingTitle;
    final pendingText = _pendingText;
    if (pendingTitle != null || pendingText != null) {
      unawaited(
        ref
            .read(todayViewModelProvider.notifier)
            .saveManualContent(
              title: pendingTitle ?? _titleController.text,
              text: pendingText ?? _textController.text,
            ),
      );
    }
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayViewModelProvider);
    final todayValue = today.value;
    final timeFormat = ref.watch(
      settingsViewModelProvider.select(
        (settings) => settings.value?.timeFormat ?? TimeFormat.hour24,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: today.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _TodayError(
            onRetry: () => ref.read(todayViewModelProvider.notifier).refresh(),
          ),
          data: (today) {
            if (_loadedDate != today.dateKey) {
              _loadedDate = today.dateKey;
              _titleController.text = today.title;
              _textController.text = today.text;
            }
            return _TodayContent(
              today: today,
              titleController: _titleController,
              textController: _textController,
              timeFormat: timeFormat,
              onManualContentChanged: _queueAutoSave,
              onTextEditingFinished: _flushAutoSave,
              onMoodSelected: (mood) =>
                  ref.read(todayViewModelProvider.notifier).setMood(mood),
              onAutomaticModeChanged: _changeMode,
              onEditSnippet: (item) =>
                  _showSnippetEditor(today, timeFormat, item: item),
              onDeleteSnippet: _deleteSnippet,
              onDeleteImage: _deleteImage,
              onDeleteVoiceMemo: _deleteVoiceMemo,
              onPickImages: _pickImages,
              onRecordVoiceMemo: () => _recordVoiceMemo(today.dateKey),
            );
          },
        ),
      ),
      floatingActionButton: todayValue == null || !todayValue.isAutomaticMode
          ? null
          : FloatingActionButton(
              tooltip: 'Add snippet',
              onPressed: todayValue.isAddingSnippet
                  ? null
                  : () => _showSnippetEditor(todayValue, timeFormat),
              child: todayValue.isAddingSnippet
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_note_rounded),
            ),
    );
  }

  void _queueAutoSave() {
    _pendingTitle = _titleController.text;
    _pendingText = _textController.text;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 750), _flushAutoSave);
  }

  Future<void> _flushAutoSave() async {
    _autoSaveTimer?.cancel();
    if (_saveInProgress) return;

    final title = _pendingTitle;
    final text = _pendingText;
    if (title == null && text == null) return;
    _pendingTitle = null;
    _pendingText = null;
    _saveInProgress = true;
    try {
      await ref
          .read(todayViewModelProvider.notifier)
          .saveManualContent(
            title: title ?? _titleController.text,
            text: text ?? _textController.text,
          );
    } catch (_) {
      _pendingTitle = title;
      _pendingText = text;
      if (mounted) _showError('Could not autosave your changes.');
    } finally {
      _saveInProgress = false;
      if ((_pendingTitle != null || _pendingText != null) && mounted) {
        _autoSaveTimer = Timer(
          const Duration(milliseconds: 750),
          _flushAutoSave,
        );
      }
    }
  }

  Future<void> _changeMode(bool isAutomatic) async {
    if (isAutomatic) await _flushAutoSave();
    await ref
        .read(todayViewModelProvider.notifier)
        .setAutomaticMode(isAutomatic);
  }

  Future<void> _showSnippetEditor(
    TodayState today,
    TimeFormat timeFormat, {
    TimelineItem? item,
  }) async {
    final draft = await showDialog<_SnippetDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SnippetDialog(
        dateKey: today.dateKey,
        timeFormat: timeFormat,
        locationLabel: item?.locationLabel ?? today.locationLabel,
        weatherLabel: item?.weatherLabel ?? today.weatherLabel,
        item: item,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      final viewModel = ref.read(todayViewModelProvider.notifier);
      if (item == null) {
        await viewModel.addSnippet(
          occurredAt: draft.occurredAt,
          text: draft.text,
          mood: draft.mood,
          images: draft.newImages,
          voiceMemoLocations: draft.newVoiceMemoLocations,
          locationLabel: today.locationLabel,
          weatherLabel: today.weatherLabel,
        );
      } else {
        await viewModel.updateSnippet(
          original: item,
          text: draft.text,
          mood: draft.mood,
          retainedImageLocations: draft.retainedImageLocations,
          newImages: draft.newImages,
          retainedVoiceMemoLocations: draft.retainedVoiceMemoLocations,
          newVoiceMemoLocations: draft.newVoiceMemoLocations,
        );
      }
    } catch (_) {
      if (mounted) _showError('Could not save that snippet.');
    }
  }

  Future<void> _pickImages() async {
    try {
      await ref.read(todayViewModelProvider.notifier).pickImages();
    } catch (_) {
      if (mounted) _showError('Could not add those images. Please try again.');
    }
  }

  Future<void> _recordVoiceMemo(String dateKey) async {
    try {
      final recordedPath = await showVoiceMemoDialog(context, dateKey: dateKey);
      if (recordedPath == null || !mounted) return;
      await ref
          .read(todayViewModelProvider.notifier)
          .addVoiceMemo(recordedPath);
    } catch (_) {
      if (mounted) {
        _showError('Could not add that voice memo.');
      }
    }
  }

  Future<void> _deleteImage(String imageLocation) async {
    if (!await _confirmDelete('image')) return;
    try {
      await ref
          .read(todayViewModelProvider.notifier)
          .deleteImage(imageLocation);
    } catch (_) {
      if (mounted) _showError('Could not delete that image.');
    }
  }

  Future<void> _deleteVoiceMemo(String audioLocation) async {
    if (!await _confirmDelete('voice memo')) return;
    try {
      await ref
          .read(todayViewModelProvider.notifier)
          .deleteVoiceMemo(audioLocation);
    } catch (_) {
      if (mounted) _showError('Could not delete that voice memo.');
    }
  }

  Future<void> _deleteSnippet(TimelineItem item) async {
    if (!await _confirmDelete('snippet')) return;
    try {
      await ref.read(todayViewModelProvider.notifier).deleteSnippet(item);
    } catch (_) {
      if (mounted) _showError('Could not delete that snippet.');
    }
  }

  Future<bool> _confirmDelete(String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $itemName?'),
        content: itemName == 'snippet'
            ? null
            : Text('This $itemName will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// Lays out either automatic mode or manual mode below the page heading.
class _TodayContent extends StatelessWidget {
  const _TodayContent({
    required this.today,
    required this.titleController,
    required this.textController,
    required this.timeFormat,
    required this.onManualContentChanged,
    required this.onTextEditingFinished,
    required this.onMoodSelected,
    required this.onAutomaticModeChanged,
    required this.onEditSnippet,
    required this.onDeleteSnippet,
    required this.onDeleteImage,
    required this.onDeleteVoiceMemo,
    required this.onPickImages,
    required this.onRecordVoiceMemo,
  });

  final TodayState today;
  final TextEditingController titleController;
  final TextEditingController textController;
  final TimeFormat timeFormat;
  final VoidCallback onManualContentChanged;
  final VoidCallback onTextEditingFinished;
  final ValueChanged<String> onMoodSelected;
  final ValueChanged<bool> onAutomaticModeChanged;
  final ValueChanged<TimelineItem> onEditSnippet;
  final ValueChanged<TimelineItem> onDeleteSnippet;
  final ValueChanged<String> onDeleteImage;
  final ValueChanged<String> onDeleteVoiceMemo;
  final VoidCallback onPickImages;
  final VoidCallback onRecordVoiceMemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 116),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Today',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.normal,
                  letterSpacing: -1,
                ),
              ),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(value: true, label: Text('Auto')),
                ButtonSegment(value: false, label: Text('Manual')),
              ],
              selected: {today.isAutomaticMode},
              onSelectionChanged: (selection) =>
                  onAutomaticModeChanged(selection.first),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          today.dateLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ContextPill(
                icon: Icons.location_on_outlined,
                label: today.locationLabel,
              ),
              const SizedBox(width: 10),
              _ContextPill(
                icon: Icons.cloud_outlined,
                label: today.weatherLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        if (today.isAutomaticMode)
          _TimelineMapSection(
            items: today.timelineItems,
            timeFormat: timeFormat,
            currentLocation: today.locationLabel,
            currentWeather: today.weatherLabel,
            currentStaySince: today.currentStaySince,
            latitude: today.latitude,
            longitude: today.longitude,
            onItemTap: onEditSnippet,
            onItemDelete: onDeleteSnippet,
          )
        else ...[
          TextField(
            controller: titleController,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onManualContentChanged(),
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              onTextEditingFinished();
            },
            decoration: const InputDecoration(hintText: 'Title'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: textController,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onManualContentChanged(),
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              onTextEditingFinished();
            },
            decoration: InputDecoration(
              hintText: 'Write about today...',
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
          const SizedBox(height: 12),
          Row(
            children: [
              MoodPicker(selectedMood: today.mood, onSelected: onMoodSelected),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Record voice memo',
                onPressed: onRecordVoiceMemo,
                icon: Icon(Icons.mic_none_rounded, color: colors.primary),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Add images',
                onPressed: today.isPickingImages ? null : onPickImages,
                icon: today.isPickingImages
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                today.isSavingText ? 'Saving...' : 'Changes save automatically',
                key: ValueKey(today.isSavingText),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (today.voiceMemoLocations.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Voice memos',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            for (
              var index = 0;
              index < today.voiceMemoLocations.length;
              index++
            ) ...[
              VoiceMemoPlayer(
                audioLocation: today.voiceMemoLocations[index],
                memoNumber: index + 1,
                showProgress: true,
                onDelete: () =>
                    onDeleteVoiceMemo(today.voiceMemoLocations[index]),
              ),
              if (index != today.voiceMemoLocations.length - 1)
                const SizedBox(height: 8),
            ],
          ],
          if (today.imageLocations.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Photos',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: today.imageLocations.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _DiaryImage(
                  imageLocation: today.imageLocations[index],
                  onDelete: () => onDeleteImage(today.imageLocations[index]),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// Keeps the Timeline/Map tab choice local to this part of the page.
class _TimelineMapSection extends StatefulWidget {
  const _TimelineMapSection({
    required this.items,
    required this.timeFormat,
    required this.currentLocation,
    required this.currentWeather,
    required this.currentStaySince,
    required this.latitude,
    required this.longitude,
    required this.onItemTap,
    required this.onItemDelete,
  });

  final List<TimelineItem> items;
  final TimeFormat timeFormat;
  final String currentLocation;
  final String currentWeather;
  final DateTime? currentStaySince;
  final double? latitude;
  final double? longitude;
  final ValueChanged<TimelineItem> onItemTap;
  final ValueChanged<TimelineItem> onItemDelete;

  @override
  State<_TimelineMapSection> createState() => _TimelineMapSectionState();
}

class _TimelineMapSectionState extends State<_TimelineMapSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging ||
        _selectedTab == _tabController.index) {
      return;
    }
    setState(() => _selectedTab = _tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Timeline'),
            Tab(text: 'Map'),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _selectedTab == 0
              ? _TimelineSection(
                  key: const ValueKey('timeline'),
                  items: widget.items,
                  timeFormat: widget.timeFormat,
                  currentLocation: widget.currentLocation,
                  currentWeather: widget.currentWeather,
                  currentStaySince: widget.currentStaySince,
                  onItemTap: widget.onItemTap,
                  onItemDelete: widget.onItemDelete,
                )
              : _CurrentLocationMap(
                  key: const ValueKey('map'),
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  locationLabel: widget.currentLocation,
                ),
        ),
      ],
    );
  }
}

// Shows the current coordinates on the device map tiles.
class _CurrentLocationMap extends StatelessWidget {
  const _CurrentLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationLabel,
  });

  final double? latitude;
  final double? longitude;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final latitude = this.latitude;
    final longitude = this.longitude;

    if (latitude == null || longitude == null) {
      final isLoading = locationLabel == 'Finding your location...';
      return Container(
        height: 330,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  Icon(
                    Icons.location_off_outlined,
                    size: 38,
                    color: colors.onSurfaceVariant,
                  ),
                const SizedBox(height: 14),
                Text(
                  locationLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentPosition = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 330,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey('$latitude,$longitude'),
              options: MapOptions(
                initialCenter: currentPosition,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.chronologe',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPosition,
                      width: 48,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.onPrimary,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: Align(
                alignment: Alignment.topLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 17,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Draws the automatic events in time order.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    super.key,
    required this.items,
    required this.timeFormat,
    required this.currentLocation,
    required this.currentWeather,
    required this.currentStaySince,
    required this.onItemTap,
    required this.onItemDelete,
  });

  final List<TimelineItem> items;
  final TimeFormat timeFormat;
  final String currentLocation;
  final String currentWeather;
  final DateTime? currentStaySince;
  final ValueChanged<TimelineItem> onItemTap;
  final ValueChanged<TimelineItem> onItemDelete;

  @override
  Widget build(BuildContext context) {
    final hasStayStatus = currentStaySince != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty)
          _CurrentContextTimelineItem(
            occurredAt: DateTime.now(),
            timeFormat: timeFormat,
            locationLabel: currentLocation,
            weatherLabel: currentWeather,
          )
        else
          for (var index = 0; index < items.length; index++)
            _TimelineItemCard(
              item: items[index],
              timeFormat: timeFormat,
              isLast: index == items.length - 1 && !hasStayStatus,
              onTap: () => onItemTap(items[index]),
              onDelete: () => onItemDelete(items[index]),
            ),
        if (hasStayStatus)
          _HereSinceStatus(since: currentStaySince!, timeFormat: timeFormat),
      ],
    );
  }
}

// Shows the beginning of the current stationary period below the latest event.
class _HereSinceStatus extends StatelessWidget {
  const _HereSinceStatus({required this.since, required this.timeFormat});

  final DateTime since;
  final TimeFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final localSince = since.toLocal();
    final now = DateTime.now();
    final isToday =
        localSince.year == now.year &&
        localSince.month == now.month &&
        localSince.day == now.day;
    final clock = formatClockTime(
      localSince,
      use24Hour: timeFormat == TimeFormat.hour24,
    );
    final label = isToday
        ? clock
        : '${MaterialLocalizations.of(context).formatMediumDate(localSince)}, '
              '$clock';

    return Padding(
      padding: const EdgeInsets.only(left: 86, bottom: 18),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            'Here since $label',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CurrentContextTimelineItem extends StatelessWidget {
  const _CurrentContextTimelineItem({
    required this.occurredAt,
    required this.timeFormat,
    required this.locationLabel,
    required this.weatherLabel,
  });

  final DateTime occurredAt;
  final TimeFormat timeFormat;
  final String locationLabel;
  final String weatherLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            formatClockTime(
              occurredAt,
              use24Hour: timeFormat == TimeFormat.hour24,
            ),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _TimelineContext(
                locationLabel: locationLabel,
                weatherLabel: weatherLabel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineItemCard extends StatelessWidget {
  const _TimelineItemCard({
    required this.item,
    required this.timeFormat,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
  });

  final TimelineItem item;
  final TimeFormat timeFormat;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emoji = moodEmoji(item.mood);
    final isHealthItem = item.source.startsWith('health:');
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
                child: InkWell(
                  onTap: isHealthItem ? null : onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.locationLabel.isNotEmpty ||
                            item.weatherLabel.isNotEmpty ||
                            !isHealthItem) ...[
                          Row(
                            children: [
                              Expanded(
                                child:
                                    item.locationLabel.isEmpty &&
                                        item.weatherLabel.isEmpty
                                    ? const SizedBox.shrink()
                                    : _TimelineContext(
                                        locationLabel: item.locationLabel,
                                        weatherLabel: item.weatherLabel,
                                      ),
                              ),
                              if (!isHealthItem) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Delete snippet',
                                  onPressed: onDelete,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (item.text.isNotEmpty)
                          Text(
                            item.text,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        if (emoji != null) ...[
                          const SizedBox(height: 6),
                          Text(emoji, style: const TextStyle(fontSize: 24)),
                        ],
                        if (item.imageLocations.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 96,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: item.imageLocations.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) => ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 128,
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
          ),
        ],
      ),
    );
  }
}

class _TimelineContext extends StatelessWidget {
  const _TimelineContext({
    required this.locationLabel,
    required this.weatherLabel,
  });

  final String locationLabel;
  final String weatherLabel;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (locationLabel.isNotEmpty)
            _TimelineContextRow(
              icon: Icons.location_on_outlined,
              label: locationLabel,
              textStyle: textStyle,
            ),
          if (locationLabel.isNotEmpty && weatherLabel.isNotEmpty)
            const SizedBox(width: 14),
          if (weatherLabel.isNotEmpty)
            _TimelineContextRow(
              icon: Icons.cloud_outlined,
              label: weatherLabel,
              textStyle: textStyle,
            ),
        ],
      ),
    );
  }
}

class _TimelineContextRow extends StatelessWidget {
  const _TimelineContextRow({
    required this.icon,
    required this.label,
    required this.textStyle,
  });

  final IconData icon;
  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, maxLines: 1, style: textStyle),
      ],
    );
  }
}

// Temporary form values returned by the add/edit snippet dialog.
class _SnippetDraft {
  const _SnippetDraft({
    required this.occurredAt,
    required this.text,
    required this.mood,
    required this.retainedImageLocations,
    required this.newImages,
    required this.retainedVoiceMemoLocations,
    required this.newVoiceMemoLocations,
  });

  final DateTime occurredAt;
  final String text;
  final String mood;
  final List<String> retainedImageLocations;
  final List<XFile> newImages;
  final List<String> retainedVoiceMemoLocations;
  final List<String> newVoiceMemoLocations;
}

// Popup used to add a new timeline snippet or edit an existing one.
class _SnippetDialog extends StatefulWidget {
  const _SnippetDialog({
    required this.dateKey,
    required this.timeFormat,
    required this.locationLabel,
    required this.weatherLabel,
    this.item,
  });

  final String dateKey;
  final TimeFormat timeFormat;
  final String locationLabel;
  final String weatherLabel;
  final TimelineItem? item;

  @override
  State<_SnippetDialog> createState() => _SnippetDialogState();
}

class _SnippetDialogState extends State<_SnippetDialog> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _controller;
  late final DateTime _occurredAt;
  late final List<String> _retainedImageLocations;
  final List<XFile> _newImages = [];
  late final List<String> _retainedVoiceMemoLocations;
  final List<String> _newVoiceMemoLocations = [];
  late String _mood;
  bool _isClosing = false;
  bool _keepNewVoiceMemos = false;

  bool get _canSave =>
      _controller.text.trim().isNotEmpty ||
      _mood.isNotEmpty ||
      _retainedImageLocations.isNotEmpty ||
      _newImages.isNotEmpty ||
      _retainedVoiceMemoLocations.isNotEmpty ||
      _newVoiceMemoLocations.isNotEmpty;

  bool get _hasAttachments =>
      _retainedImageLocations.isNotEmpty ||
      _newImages.isNotEmpty ||
      _retainedVoiceMemoLocations.isNotEmpty ||
      _newVoiceMemoLocations.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _controller = TextEditingController(text: item?.text ?? '');
    _occurredAt = item?.occurredAt ?? DateTime.now();
    _mood = item?.mood ?? '';
    _retainedImageLocations = [...?item?.imageLocations];
    _retainedVoiceMemoLocations = [...?item?.voiceMemoLocations];
  }

  @override
  void dispose() {
    _controller.dispose();
    if (!_keepNewVoiceMemos) unawaited(_deleteNewVoiceMemoDrafts());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_discard());
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: 370,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatClockTime(
                          _occurredAt,
                          use24Hour: widget.timeFormat == TimeFormat.hour24,
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close snippet',
                      onPressed: _isClosing ? null : _discard,
                      icon: Icon(Icons.close_rounded, color: colors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.locationLabel.isNotEmpty ||
                    widget.weatherLabel.isNotEmpty)
                  _TimelineContext(
                    locationLabel: widget.locationLabel,
                    weatherLabel: widget.weatherLabel,
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  autofocus: widget.item == null,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'What happened?',
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    contentPadding: const EdgeInsets.all(16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    MoodPicker(
                      selectedMood: _mood,
                      onSelected: (mood) => setState(() => _mood = mood),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Record voice memo',
                      onPressed: _isClosing ? null : _recordVoiceMemo,
                      icon: Icon(Icons.mic_none_rounded, color: colors.primary),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Add images',
                      onPressed: _isClosing ? null : _pickImages,
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                if (_hasAttachments) ...[
                  const SizedBox(height: 8),
                  _buildAttachments(),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isClosing || !_canSave ? null : _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    final colors = Theme.of(context).colorScheme;
    final imageCount = _retainedImageLocations.length + _newImages.length;
    final voiceMemoCount =
        _retainedVoiceMemoLocations.length + _newVoiceMemoLocations.length;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 138),
      child: ListView(
        shrinkWrap: true,
        children: [
          if (imageCount > 0)
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageCount,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isRetained = index < _retainedImageLocations.length;
                  final filePath = isRetained
                      ? _retainedImageLocations[index]
                      : _newImages[index - _retainedImageLocations.length].path;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 96,
                          height: 74,
                          child: EncryptedMediaImage(filePath: filePath),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: IconButton.filled(
                          tooltip: 'Remove image',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            if (isRetained) {
                              _retainedImageLocations.removeAt(index);
                            } else {
                              _newImages.removeAt(
                                index - _retainedImageLocations.length,
                              );
                            }
                          }),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surfaceContainerHighest,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (imageCount > 0 && voiceMemoCount > 0) const SizedBox(height: 8),
          if (voiceMemoCount > 0)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var index = 0; index < voiceMemoCount; index++)
                  InputChip(
                    avatar: const Icon(Icons.mic_rounded, size: 18),
                    label: Text('Voice memo ${index + 1}'),
                    deleteIcon: Icon(
                      Icons.close_rounded,
                      color: colors.primary,
                    ),
                    onDeleted: () => _removeVoiceMemo(index),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage(
      maxWidth: diaryImageMaxDimension,
      maxHeight: diaryImageMaxDimension,
      imageQuality: diaryImageQuality,
      limit: 10,
      requestFullMetadata: false,
    );
    if (mounted && images.isNotEmpty) {
      setState(() => _newImages.addAll(images));
    }
  }

  Future<void> _recordVoiceMemo() async {
    final memo = await showVoiceMemoDialog(context, dateKey: widget.dateKey);
    if (mounted && memo != null) {
      setState(() => _newVoiceMemoLocations.add(memo));
    }
  }

  Future<void> _removeVoiceMemo(int index) async {
    if (index < _retainedVoiceMemoLocations.length) {
      setState(() => _retainedVoiceMemoLocations.removeAt(index));
      return;
    }

    final newIndex = index - _retainedVoiceMemoLocations.length;
    final location = _newVoiceMemoLocations.removeAt(newIndex);
    setState(() {});
    await deleteFileIfPresent(location);
  }

  Future<void> _discard() async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    await _deleteNewVoiceMemoDrafts();
    _newVoiceMemoLocations.clear();
    if (mounted) Navigator.pop(context);
  }

  void _save() {
    if (_isClosing || !_canSave) return;
    _isClosing = true;
    _keepNewVoiceMemos = true;
    Navigator.pop(
      context,
      _SnippetDraft(
        occurredAt: _occurredAt,
        text: _controller.text,
        mood: _mood,
        retainedImageLocations: List.unmodifiable(_retainedImageLocations),
        newImages: List.unmodifiable(_newImages),
        retainedVoiceMemoLocations: List.unmodifiable(
          _retainedVoiceMemoLocations,
        ),
        newVoiceMemoLocations: List.unmodifiable(_newVoiceMemoLocations),
      ),
    );
  }

  Future<void> _deleteNewVoiceMemoDrafts() async {
    for (final location in _newVoiceMemoLocations) {
      await deleteFileIfPresent(location);
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// Displays one encrypted diary image with a delete button.
class _DiaryImage extends StatelessWidget {
  const _DiaryImage({required this.imageLocation, required this.onDelete});

  final String imageLocation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: EncryptedMediaImage(filePath: imageLocation),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              tooltip: 'Delete image',
              onPressed: onDelete,
              style: IconButton.styleFrom(
                backgroundColor: colors.scrim.withValues(alpha: 0.62),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayError extends StatelessWidget {
  const _TodayError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('Today could not be loaded.'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
