import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/background_location_service.dart';
import '../../../core/services/android_background_health_service.dart';
import '../../../core/services/diagnostic_log_service.dart';
import '../../authentication/viewmodels/authentication_view_model.dart';
import '../../authentication/views/authentication_page.dart';
import '../../entries/viewmodels/trash_view_model.dart';
import '../../entries/views/trash_page.dart';
import '../../integrations/health/viewmodels/health_integration_view_model.dart';
import '../../notifications/viewmodels/notification_view_model.dart';
import '../../tracking/viewmodels/background_tracking_controller.dart';
import '../models/app_settings.dart';
import '../viewmodels/cloud_backup_view_model.dart';
import '../viewmodels/settings_view_model.dart';

/// Displays account, personalization, diary, and storage controls.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

enum _SettingsSection {
  account,
  personalization,
  automaticDiary,
  notifications,
  integrations,
  news,
  backups,
  storage,
  diagnostics,
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
  _SettingsSection? _openSection;

  @override
  void dispose() {
    _newsInterestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsViewModelProvider);
    final signedInUser = ref.watch(authenticatedUserProvider).value;
    final authentication = ref.watch(authenticationViewModelProvider);
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
            const SizedBox(height: 16),
            _CollapsibleSettingsSection(
              title: 'Account',
              icon: Icons.account_circle_outlined,
              isExpanded: _openSection == _SettingsSection.account,
              onTap: () => _toggleSection(_SettingsSection.account),
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(
                        signedInUser == null
                            ? 'Sign in'
                            : signedInUser.displayName?.trim().isNotEmpty ==
                                  true
                            ? signedInUser.displayName!
                            : 'Account',
                      ),
                      subtitle: Text(
                        signedInUser?.email ?? 'Sync and back up your diary',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _openAuthentication,
                    ),
                    if (signedInUser != null) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Display name'),
                        subtitle: Text(
                          signedInUser.displayName?.trim().isNotEmpty == true
                              ? signedInUser.displayName!
                              : 'Add your name',
                        ),
                        trailing: authentication.isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.edit_outlined),
                        onTap: authentication.isLoading
                            ? null
                            : () => _changeDisplayName(
                                signedInUser.displayName ?? '',
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _CollapsibleSettingsSection(
              title: 'Personalization',
              icon: Icons.tune_rounded,
              isExpanded: _openSection == _SettingsSection.personalization,
              onTap: () => _toggleSection(_SettingsSection.personalization),
              child: _PersonalizationCard(
                settings: settings,
                accentColors: _accentColors,
              ),
            ),
            _CollapsibleSettingsSection(
              title: 'Automatic diary',
              icon: Icons.auto_awesome_outlined,
              isExpanded: _openSection == _SettingsSection.automaticDiary,
              onTap: () => _toggleSection(_SettingsSection.automaticDiary),
              child: const _BackgroundLocationCard(),
            ),
            _CollapsibleSettingsSection(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              isExpanded: _openSection == _SettingsSection.notifications,
              onTap: () => _toggleSection(_SettingsSection.notifications),
              child: const _NotificationsCard(),
            ),
            _CollapsibleSettingsSection(
              title: 'Integrations',
              icon: Icons.extension_outlined,
              isExpanded: _openSection == _SettingsSection.integrations,
              onTap: () => _toggleSection(_SettingsSection.integrations),
              child: const _HealthIntegrationCard(),
            ),
            _CollapsibleSettingsSection(
              title: 'News interests',
              icon: Icons.newspaper_outlined,
              isExpanded: _openSection == _SettingsSection.news,
              onTap: () => _toggleSection(_SettingsSection.news),
              child: Card(
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
            ),
            _CollapsibleSettingsSection(
              title: 'Backups',
              icon: Icons.cloud_outlined,
              isExpanded: _openSection == _SettingsSection.backups,
              onTap: () => _toggleSection(_SettingsSection.backups),
              child: const _CloudBackupCard(),
            ),
            _CollapsibleSettingsSection(
              title: 'Storage',
              icon: Icons.storage_outlined,
              isExpanded: _openSection == _SettingsSection.storage,
              onTap: () => _toggleSection(_SettingsSection.storage),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Trash'),
                  subtitle: const Text('Deleted entries are kept for 30 days'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openTrash,
                ),
              ),
            ),
            _CollapsibleSettingsSection(
              title: 'Diagnostics',
              icon: Icons.bug_report_outlined,
              isExpanded: _openSection == _SettingsSection.diagnostics,
              onTap: () => _toggleSection(_SettingsSection.diagnostics),
              child: const _DiagnosticsCard(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Opens one section at a time, or closes it when tapped again.
  void _toggleSection(_SettingsSection section) {
    setState(() {
      _openSection = _openSection == section ? null : section;
    });
  }

  Future<void> _addNewsInterest() async {
    final interest = _newsInterestController.text;
    if (interest.trim().isEmpty) return;

    await ref
        .read(settingsViewModelProvider.notifier)
        .addNewsInterest(interest);
    _newsInterestController.clear();
  }

  void _openAuthentication() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const AuthenticationPage()),
    );
  }

  void _openTrash() {
    ref.invalidate(trashViewModelProvider);
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (context) => const TrashPage()));
  }

  Future<void> _changeDisplayName(String currentName) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _DisplayNameDialog(currentName: currentName),
    );
    if (!mounted || name == null) return;

    final success = await ref
        .read(authenticationViewModelProvider.notifier)
        .updateDisplayName(name);
    if (!mounted) return;

    final message = success
        ? 'Display name updated.'
        : ref.read(authenticationViewModelProvider).errorMessage ??
              'Could not update your name.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// A tappable Settings heading that reveals one group of controls.
class _PersonalizationCard extends ConsumerWidget {
  const _PersonalizationCard({
    required this.settings,
    required this.accentColors,
  });

  final AppSettings settings;
  final List<int> accentColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsController = ref.read(settingsViewModelProvider.notifier);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined),
                const SizedBox(width: 10),
                Text('Appearance', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          SwitchListTile.adaptive(
            title: const Text('Dark theme'),
            subtitle: const Text('Switch between light and dark mode'),
            value: settings.isDarkMode,
            onChanged: settingsController.setDarkMode,
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
                    for (var index = 0; index < accentColors.length; index++)
                      _AccentColorBlock(
                        colorValue: accentColors[index],
                        colorNumber: index + 1,
                        isSelected:
                            settings.accentColorValue == accentColors[index],
                        onTap: () => settingsController.setAccentColor(
                          accentColors[index],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.straighten_outlined),
                const SizedBox(width: 10),
                Text('Units & time', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          _UnitSettingRow<TemperatureUnit>(
            title: 'Temperature',
            segments: const [
              ButtonSegment(value: TemperatureUnit.celsius, label: Text('°C')),
              ButtonSegment(
                value: TemperatureUnit.fahrenheit,
                label: Text('°F'),
              ),
            ],
            selected: settings.temperatureUnit,
            onChanged: settingsController.setTemperatureUnit,
          ),
          const Divider(height: 1),
          _UnitSettingRow<DistanceUnit>(
            title: 'Distance',
            segments: const [
              ButtonSegment(value: DistanceUnit.kilometers, label: Text('km')),
              ButtonSegment(value: DistanceUnit.miles, label: Text('mi')),
            ],
            selected: settings.distanceUnit,
            onChanged: settingsController.setDistanceUnit,
          ),
          const Divider(height: 1),
          _UnitSettingRow<TimeFormat>(
            title: 'Time',
            segments: const [
              ButtonSegment(value: TimeFormat.hour24, label: Text('24hr')),
              ButtonSegment(value: TimeFormat.hour12, label: Text('12hr')),
            ],
            selected: settings.timeFormat,
            onChanged: settingsController.setTimeFormat,
          ),
        ],
      ),
    );
  }
}

class _CollapsibleSettingsSection extends StatelessWidget {
  const _CollapsibleSettingsSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
    required this.child,
  });

  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: colors.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// Shows location status and Android's battery restriction state.
class _BackgroundLocationCard extends ConsumerStatefulWidget {
  const _BackgroundLocationCard();

  @override
  ConsumerState<_BackgroundLocationCard> createState() =>
      _BackgroundLocationCardState();
}

class _BackgroundLocationCardState
    extends ConsumerState<_BackgroundLocationCard>
    with WidgetsBindingObserver {
  late Future<AndroidBackgroundHealth> _backgroundHealth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _backgroundHealth = AndroidBackgroundHealthService.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _backgroundHealth = AndroidBackgroundHealthService.check(
          writeLog: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingEnabled = ref.watch(
      settingsViewModelProvider.select(
        (settings) => settings.value?.automaticTrackingEnabled ?? true,
      ),
    );
    final trackingStatus = ref.watch(
      backgroundTrackingControllerProvider.select(
        (status) => status.value ?? BackgroundTrackingStatus.starting,
      ),
    );

    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Background location'),
            subtitle: Text(trackingStatus.label),
            value: trackingEnabled,
            onChanged: (value) => ref
                .read(settingsViewModelProvider.notifier)
                .setAutomaticTrackingEnabled(value),
          ),
          FutureBuilder<AndroidBackgroundHealth>(
            future: _backgroundHealth,
            builder: (context, snapshot) {
              final health = snapshot.data;
              if (health == null || !health.isSupported) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      health.needsAttention
                          ? Icons.battery_alert_outlined
                          : Icons.battery_saver_outlined,
                    ),
                    title: const Text('Background battery access'),
                    subtitle: Text(
                      health.needsAttention
                          ? '${health.label}. Open app settings, choose '
                                'Battery, then select Unrestricted.'
                          : health.label,
                    ),
                    trailing: health.needsAttention
                        ? const Icon(Icons.chevron_right_rounded)
                        : const Icon(Icons.check_circle_outline_rounded),
                    onTap: health.needsAttention
                        ? AndroidBackgroundHealthService.openAppBatterySettings
                        : null,
                  ),
                ],
              );
            },
          ),
          if (trackingEnabled &&
              trackingStatus != BackgroundTrackingStatus.active &&
              trackingStatus != BackgroundTrackingStatus.starting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(backgroundTrackingControllerProvider.notifier)
                        .openSettings(),
                    child: const Text('Open settings'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => ref
                        .read(backgroundTrackingControllerProvider.notifier)
                        .retry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Keeps health-sync messages from rebuilding the whole Settings page.
class _HealthIntegrationCard extends ConsumerWidget {
  const _HealthIntegrationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthEnabled = ref.watch(
      settingsViewModelProvider.select(
        (settings) => settings.value?.healthIntegrationEnabled ?? false,
      ),
    );
    final healthIntegration = ref.watch(healthIntegrationViewModelProvider);
    final healthStatus = healthIntegration.value;

    return Card(
      child: SwitchListTile.adaptive(
        secondary: const Icon(Icons.favorite_outline_rounded),
        title: const Text('Health'),
        subtitle: Text(
          healthStatus?.message ?? 'Checking health connection...',
        ),
        value: healthEnabled,
        onChanged:
            healthIntegration.isLoading || (healthStatus?.isBusy ?? false)
            ? null
            : (value) => ref
                  .read(healthIntegrationViewModelProvider.notifier)
                  .setEnabled(value),
      ),
    );
  }
}

// Displays notification controls without rebuilding the whole Settings page.
class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(
      settingsViewModelProvider.select((settings) {
        final value = settings.value ?? const AppSettings();
        return (
          enabled: value.notificationsEnabled,
          dailyEnabled: value.dailyReminderEnabled,
          hour: value.dailyReminderHour,
          minute: value.dailyReminderMinute,
          newPlacesEnabled: value.newPlacePromptsEnabled,
          timeFormat: value.timeFormat,
        );
      }),
    );
    final notificationState = ref.watch(notificationViewModelProvider);
    final status = notificationState.value;
    final reminderTime = TimeOfDay(
      hour: preferences.hour,
      minute: preferences.minute,
    );
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      reminderTime,
      alwaysUse24HourFormat: preferences.timeFormat == TimeFormat.hour24,
    );

    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Allow notifications'),
            subtitle: Text(
              status?.message ?? 'Checking notification status...',
            ),
            value: preferences.enabled,
            onChanged: notificationState.isLoading || (status?.isBusy ?? false)
                ? null
                : (value) => ref
                      .read(notificationViewModelProvider.notifier)
                      .setNotificationsEnabled(value),
          ),
          if (preferences.enabled) ...[
            const Divider(height: 1),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Daily diary reminder'),
              subtitle: const Text('Remind me to finish today\'s entry'),
              value: preferences.dailyEnabled,
              onChanged: (value) => ref
                  .read(notificationViewModelProvider.notifier)
                  .setDailyReminderEnabled(value),
            ),
            ListTile(
              enabled: preferences.dailyEnabled,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Reminder time'),
              trailing: Text(timeLabel),
              onTap: preferences.dailyEnabled
                  ? () => _pickReminderTime(context, ref, reminderTime)
                  : null,
            ),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.add_a_photo_outlined),
              title: const Text('New place prompts'),
              subtitle: const Text('Suggest taking a photo at a new place'),
              value: preferences.newPlacesEnabled,
              onChanged: (value) => ref
                  .read(notificationViewModelProvider.notifier)
                  .setNewPlacePromptsEnabled(value),
            ),
          ],
        ],
      ),
    );
  }

  // Opens the platform time picker and reschedules the daily reminder.
  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay currentTime,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (selected == null) return;
    await ref
        .read(notificationViewModelProvider.notifier)
        .setDailyReminderTime(selected.hour, selected.minute);
  }
}

// Shows the manual Firebase backup and restore controls.
class _CloudBackupCard extends ConsumerWidget {
  const _CloudBackupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsViewModelProvider.select(
        (settings) => settings.value?.backupsEnabled ?? false,
      ),
    );
    final backupState = ref.watch(cloudBackupViewModelProvider);
    final backup = backupState.value;
    final isBusy = backupState.isLoading || (backup?.isBusy ?? false);
    final lastBackup = backup?.lastBackup;

    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.cloud_outlined),
            title: const Text('Cloud backups'),
            subtitle: Text(
              lastBackup == null
                  ? 'No cloud backup yet'
                  : 'Last backup: ${_formatBackupTime(context, lastBackup)}',
            ),
            value: enabled,
            onChanged: isBusy
                ? null
                : (value) => ref
                      .read(settingsViewModelProvider.notifier)
                      .setBackupsEnabled(value),
          ),
          if (enabled) ...[
            if (isBusy)
              LinearProgressIndicator(
                value: backup?.progress == 0 ? null : backup?.progress,
              ),
            if (backup?.message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    backup!.message!,
                    style: TextStyle(
                      color: backup.status == CloudBackupStatus.error
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Backups are private and linked to your signed-in account.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: isBusy ? null : () => _backUp(context, ref),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Backup now'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy || lastBackup == null
                          ? null
                          : () => _restore(context, ref),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Restore'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBackupTime(BuildContext context, DateTime dateTime) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(dateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
    );
    return '$date, $time';
  }

  Future<void> _backUp(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(cloudBackupViewModelProvider.notifier)
        .backUp();
    if (!context.mounted) return;
    final message = ref.read(cloudBackupViewModelProvider).value?.message;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } else if (!success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cloud backup failed.')));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace local diary?'),
        content: const Text(
          'Restoring replaces the current local database with the latest '
          'cloud backup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(cloudBackupViewModelProvider.notifier).restore();
    if (!context.mounted) return;
    final message = ref.read(cloudBackupViewModelProvider).value?.message;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

// Runs and exports the temporary background-collection diagnostic log.
class _DiagnosticsCard extends ConsumerStatefulWidget {
  const _DiagnosticsCard();

  @override
  ConsumerState<_DiagnosticsCard> createState() => _DiagnosticsCardState();
}

class _DiagnosticsCardState extends ConsumerState<_DiagnosticsCard> {
  late Future<DiagnosticLogInfo> _info = DiagnosticLogService.getInfo();
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Temporary log for the foreground location service, movement '
              'changes, hourly backup worker, cached-location fallback, '
              'weather, and Android battery restrictions. It does not include '
              'exact coordinates, diary text, media paths, passwords, or '
              'encryption keys.',
            ),
            const SizedBox(height: 10),
            FutureBuilder<DiagnosticLogInfo>(
              future: _info,
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null) {
                  return const Text('Reading log details...');
                }
                final size = info.bytes < 1024
                    ? '${info.bytes} bytes'
                    : '${(info.bytes / 1024).toStringAsFixed(1)} KB';
                final updated = info.lastUpdated;
                final updatedText = updated == null
                    ? 'No entries yet'
                    : 'Last updated ${_formatDiagnosticTime(context, updated)}';
                return Text('$size • $updatedText');
              },
            ),
            if (_isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isBusy ? null : _runCheck,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Run check now'),
                ),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _shareLog,
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Share log'),
                ),
                TextButton.icon(
                  onPressed: _isBusy ? null : _clearLog,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDiagnosticTime(BuildContext context, DateTime dateTime) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(dateTime.toLocal()));
  }

  Future<void> _runCheck() async {
    setState(() => _isBusy = true);
    try {
      final succeeded = await ref
          .read(backgroundTrackingControllerProvider.notifier)
          .runDiagnosticCheck();
      if (!mounted) return;
      final message = succeeded
          ? 'Test completed. Check Today, then share the log if needed.'
          : 'Test failed. Share the log to see where it stopped.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      await DiagnosticLogService.record(
        'diagnostics',
        'Manual test UI failed',
        error: error,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test failed. Please share the log.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _info = DiagnosticLogService.getInfo();
        });
      }
    }
  }

  Future<void> _shareLog() async {
    setState(() => _isBusy = true);
    try {
      final logFile = await DiagnosticLogService.createShareCopy();
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          subject: 'ChronoLoge diagnostic log',
          text: 'Temporary background tracking diagnostic log.',
          files: [XFile(logFile.path, mimeType: 'text/plain')],
          fileNameOverrides: const ['chronologe-diagnostics.log'],
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } catch (error) {
      await DiagnosticLogService.record(
        'diagnostics',
        'Could not open the share sheet',
        error: error,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share the diagnostic log.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _info = DiagnosticLogService.getInfo();
        });
      }
    }
  }

  Future<void> _clearLog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear diagnostic log?'),
        content: const Text(
          'Clear it before a fresh background test so the next log is easier '
          'to read.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    await DiagnosticLogService.clear();
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _info = DiagnosticLogService.getInfo();
    });
  }
}

// Small dialog used to edit the signed-in user's display name.
class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.currentName});

  final String currentName;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Checks the name and returns it to the settings page.
  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change display name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          validator: (value) {
            final cleanName = value?.trim() ?? '';
            if (cleanName.isEmpty) return 'Enter your name.';
            if (cleanName.length < 2) return 'Enter at least 2 characters.';
            return null;
          },
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
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
