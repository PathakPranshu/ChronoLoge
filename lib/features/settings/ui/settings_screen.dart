import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/shared/providers/auth_provider.dart';
import '../../../core/themes/theme_controller.dart';
import '../../../core/notifications/notification_settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Make ChronoLoge yours.',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage your account and how your diary works.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: authState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('Unable to load your profile.'),
              data: (user) => Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.primary,
                    child: Icon(
                      Icons.person_outline,
                      color: colors.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'ChronoLoge user',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'No email available',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _SettingsSection(
            title: 'APP SETTINGS',
            onItemTap: (item) {
              if (item.title == 'Preferences') {
                _showThemeSelector(context, ref);
              } else if (item.title == 'Notifications') {
                _showNotificationSettings(context);
              } else {
                _showComingSoon(context, item.title);
              }
            },
            items: const [
              _SettingsItem(
                icon: Icons.tune_rounded,
                title: 'Preferences',
                subtitle: 'Theme and diary appearance',
              ),
              _SettingsItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Daily reminders',
              ),
              _SettingsItem(
                icon: Icons.shield_outlined,
                title: 'Privacy & Security',
                subtitle: 'App lock and biometrics',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'DIARY & INFORMATION',
            items: const [
              _SettingsItem(
                icon: Icons.auto_awesome_outlined,
                title: 'Diary Generation',
                subtitle: 'Choose how your diary is created',
              ),
              _SettingsItem(
                icon: Icons.backup_outlined,
                title: 'Backup & Recovery',
                subtitle: 'Manage your diary backups',
              ),
              _SettingsItem(
                icon: Icons.info_outline_rounded,
                title: 'App Info',
                subtitle: 'About ChronoLoge',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'ACCOUNT',
            items: const [
              _SettingsItem(
                icon: Icons.manage_accounts_outlined,
                title: 'Account',
                subtitle: 'Profile and sign-in details',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'ChronoLoge · Your days, remembered.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          final selectedMode = dialogRef.watch(themeModeProvider);

          return AlertDialog(
            title: const Text('Appearance'),
            content: RadioGroup<ThemeMode>(
              groupValue: selectedMode,
              onChanged: (mode) {
                if (mode != null) {
                  _saveTheme(dialogContext, dialogRef, mode);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _ThemeOption(
                    title: 'System default',
                    subtitle: 'Follow your device settings',
                    value: ThemeMode.system,
                  ),
                  _ThemeOption(
                    title: 'Light',
                    subtitle: 'Always use light appearance',
                    value: ThemeMode.light,
                  ),
                  _ThemeOption(
                    title: 'Dark',
                    subtitle: 'Always use dark appearance',
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    try {
      await ref.read(themeModeProvider.notifier).setThemeMode(mode);

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the appearance setting.'),
          ),
        );
      }
    }
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          final remindersEnabled = dialogRef.watch(
            dailyRemindersEnabledProvider,
          );

          return AlertDialog(
            title: const Text('Daily reminders'),
            content: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable daily reminders'),
              subtitle: const Text(
                'Receive a diary reminder every day at 8:00 PM.',
              ),
              value: remindersEnabled,
              onChanged: (enabled) {
                _saveNotificationPreference(dialogContext, dialogRef, enabled);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveNotificationPreference(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    try {
      await ref
          .read(dailyRemindersEnabledProvider.notifier)
          .setEnabled(enabled);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the reminder setting.'),
          ),
        );
      }
    }
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title will be connected in the next step.')),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final ThemeMode value;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.items,
    this.onItemTap,
  });

  final String title;
  final List<_SettingsItem> items;
  final ValueChanged<_SettingsItem>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Icon(items[i].icon, color: colors.primary),
                    title: Text(
                      items[i].title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(items[i].subtitle),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: colors.onSurfaceVariant,
                    ),
                    onTap: () {
                      if (onItemTap != null) {
                        onItemTap!(items[i]);
                      } else {
                        _showComingSoon(context, items[i].title);
                      }
                    },
                  ),
                ),
                if (i < items.length - 1)
                  Divider(height: 1, indent: 56, color: colors.outlineVariant),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title will be connected in the next step.')),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
