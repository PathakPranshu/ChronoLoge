import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/background_location_service.dart';
import '../../authentication/viewmodels/authentication_view_model.dart';
import '../../authentication/views/authentication_page.dart';
import '../../tracking/viewmodels/background_tracking_controller.dart';
import '../models/app_settings.dart';
import '../viewmodels/settings_view_model.dart';

/// Displays account, appearance, units, news, and backup controls.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _accentColors = [
    0xffa2391a,
    0xffe05d38,
    0xffef8f00,
    0xffd2a900,
    0xff557a36,
    0xff008c72,
    0xff008a9a,
    0xff3567b7,
    0xff6558c5,
    0xff76548f,
    0xffb23a73,
    0xffbf4055,
  ];

  final TextEditingController _newsInterestController = TextEditingController();

  @override
  void dispose() {
    _newsInterestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsViewModelProvider);
    final signedInUser = ref.watch(authenticatedUserProvider).value;
    final trackingStatus =
        ref.watch(backgroundTrackingControllerProvider).value ??
        BackgroundTrackingStatus.starting;

    return SafeArea(
      child: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(settingsViewModelProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Account'),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(
                  signedInUser == null
                      ? 'Sign in'
                      : signedInUser.displayName?.trim().isNotEmpty == true
                      ? signedInUser.displayName!
                      : 'Account',
                ),
                subtitle: Text(
                  signedInUser?.email ?? 'Sync and back up your diary',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openAuthentication,
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Appearance'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Dark theme'),
                    subtitle: const Text('Switch between light and dark mode'),
                    value: settings.isDarkMode,
                    onChanged: (value) => ref
                        .read(settingsViewModelProvider.notifier)
                        .setDarkMode(value),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Accent color'),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (
                              var index = 0;
                              index < _accentColors.length;
                              index++
                            )
                              _AccentColorBlock(
                                colorValue: _accentColors[index],
                                colorNumber: index + 1,
                                isSelected:
                                    settings.accentColorValue ==
                                    _accentColors[index],
                                onTap: () => ref
                                    .read(settingsViewModelProvider.notifier)
                                    .setAccentColor(_accentColors[index]),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Automatic diary'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Background location'),
                    subtitle: Text(trackingStatus.label),
                    value: settings.automaticTrackingEnabled,
                    onChanged: (value) => ref
                        .read(settingsViewModelProvider.notifier)
                        .setAutomaticTrackingEnabled(value),
                  ),
                  if (settings.automaticTrackingEnabled &&
                      trackingStatus != BackgroundTrackingStatus.active &&
                      trackingStatus != BackgroundTrackingStatus.starting)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => ref
                                .read(
                                  backgroundTrackingControllerProvider.notifier,
                                )
                                .openSettings(),
                            child: const Text('Open settings'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: () => ref
                                .read(
                                  backgroundTrackingControllerProvider.notifier,
                                )
                                .retry(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Units & time'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _UnitSettingRow<TemperatureUnit>(
                    title: 'Temperature',
                    segments: const [
                      ButtonSegment(
                        value: TemperatureUnit.celsius,
                        label: Text('°C'),
                      ),
                      ButtonSegment(
                        value: TemperatureUnit.fahrenheit,
                        label: Text('°F'),
                      ),
                    ],
                    selected: settings.temperatureUnit,
                    onChanged: (unit) => ref
                        .read(settingsViewModelProvider.notifier)
                        .setTemperatureUnit(unit),
                  ),
                  const Divider(height: 1),
                  _UnitSettingRow<DistanceUnit>(
                    title: 'Distance',
                    segments: const [
                      ButtonSegment(
                        value: DistanceUnit.kilometers,
                        label: Text('km'),
                      ),
                      ButtonSegment(
                        value: DistanceUnit.miles,
                        label: Text('mi'),
                      ),
                    ],
                    selected: settings.distanceUnit,
                    onChanged: (unit) => ref
                        .read(settingsViewModelProvider.notifier)
                        .setDistanceUnit(unit),
                  ),
                  const Divider(height: 1),
                  _UnitSettingRow<TimeFormat>(
                    title: 'Time',
                    segments: const [
                      ButtonSegment(
                        value: TimeFormat.hour24,
                        label: Text('24hr'),
                      ),
                      ButtonSegment(
                        value: TimeFormat.hour12,
                        label: Text('12hr'),
                      ),
                    ],
                    selected: settings.timeFormat,
                    onChanged: (format) => ref
                        .read(settingsViewModelProvider.notifier)
                        .setTimeFormat(format),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'News interests'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add topics you would like ChronoLoge to follow.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _newsInterestController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addNewsInterest(),
                      decoration: InputDecoration(
                        hintText: 'e.g. technology, local sports',
                        prefixIcon: const Icon(Icons.newspaper_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Add interest',
                          onPressed: _addNewsInterest,
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ),
                    if (settings.newsInterests.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final interest in settings.newsInterests)
                            InputChip(
                              label: Text(interest),
                              onDeleted: () => ref
                                  .read(settingsViewModelProvider.notifier)
                                  .removeNewsInterest(interest),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Backups'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Cloud backups'),
                    subtitle: const Text('Cloud provider not connected yet'),
                    value: settings.backupsEnabled,
                    onChanged: (value) => ref
                        .read(settingsViewModelProvider.notifier)
                        .setBackupsEnabled(value),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: settings.backupsEnabled
                            ? _showBackupMessage
                            : null,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Backup now'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  Future<void> _addNewsInterest() async {
    final interest = _newsInterestController.text;
    if (interest.trim().isEmpty) return;

    await ref
        .read(settingsViewModelProvider.notifier)
        .addNewsInterest(interest);
    _newsInterestController.clear();
  }

  void _showBackupMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cloud backup will be connected later.')),
    );
  }

  void _openAuthentication() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const AuthenticationPage()),
    );
  }
}

// Reusable two-choice control used for temperature, distance, and time.
class _UnitSettingRow<T> extends StatelessWidget {
  const _UnitSettingRow({
    required this.title,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          SegmentedButton<T>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: segments,
            selected: {selected},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

// One selectable color square in the accent-color grid.
class _AccentColorBlock extends StatelessWidget {
  const _AccentColorBlock({
    required this.colorValue,
    required this.colorNumber,
    required this.isSelected,
    required this.onTap,
  });

  final int colorValue;
  final int colorNumber;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final checkColor = color.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;

    return Semantics(
      label: 'Accent color $colorNumber',
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: isSelected
              ? Icon(Icons.check_rounded, color: checkColor, size: 24)
              : null,
        ),
      ),
    );
  }
}
