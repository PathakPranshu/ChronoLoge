import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/notification_settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remindersEnabled = ref.watch(dailyRemindersEnabledProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: const Text('Notifications'), pinned: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Stay consistent with your diary.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose whether ChronoLoge should remind you to '
                  'write about your day.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    title: const Text('Daily reminders'),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Receive a diary reminder every day at 8:00 PM.',
                      ),
                    ),
                    value: remindersEnabled,
                    onChanged: (enabled) async {
                      try {
                        await ref
                            .read(dailyRemindersEnabledProvider.notifier)
                            .setEnabled(enabled);
                      } catch (_) {
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not update the reminder setting.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
