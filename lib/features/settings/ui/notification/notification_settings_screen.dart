import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/notification_settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final appBarBackgroundColor = Color.alphaBlend(
      colors.surfaceTint.withValues(alpha: 0.1),
      colors.surfaceContainer,
    );

    final notificationState = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: appBarBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Material(
        clipBehavior: Clip.antiAlias,
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: notificationState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('Unable to load notification settings.'),
              ),
              data: (settings) => ListView(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Stay Consistent with your diary.',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose whether ChronoLoge should remind you to write about your day.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Daily Reminders Card
                  _DailyReminderCard(
                    isEnabled: settings.isEnabled,
                    reminderTime: settings.reminderTime,
                    onToggle: (value) => _handleToggle(context, ref, value),
                    onTapTime: () =>
                        _pickReminderTime(context, ref, settings.reminderTime),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref
          .read(notificationSettingsProvider.notifier)
          .setNotificationsEnabled(value);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update notification preference.'),
          ),
        );
      }
    }
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay initialTime,
  ) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (pickedTime != null && context.mounted) {
      try {
        await ref
            .read(notificationSettingsProvider.notifier)
            .setReminderTime(pickedTime);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save the reminder time.')),
          );
        }
      }
    }
  }
}

class _DailyReminderCard extends StatelessWidget {
  final bool isEnabled;
  final TimeOfDay reminderTime;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTapTime;

  const _DailyReminderCard({
    required this.isEnabled,
    required this.reminderTime,
    required this.onToggle,
    required this.onTapTime,
  });

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final hourStr = hour.toString().padLeft(2, '0');
    final minStr = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'am' : 'pm';
    return '$hourStr:$minStr $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: isEnabled ? onTapTime : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily reminders',
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Receive a diary reminder everyday at',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: textTheme.headlineLarge!.copyWith(
                      color: isEnabled
                          ? colors.primary
                          : colors.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    child: Text(_formatTime(reminderTime)),
                  ),
                  Switch(value: isEnabled, onChanged: onToggle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
