import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../viewmodels/privacy_security_viewmodel.dart';

class PrivacySecurityScreen extends ConsumerWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final appBarBackgroundColor = Color.alphaBlend(
      colors.surfaceTint.withValues(alpha: 0.1),
      colors.surfaceContainer,
    );

    final securityState = ref.watch(privacySecurityViewModelProvider);

    return Scaffold(
      backgroundColor: appBarBackgroundColor,
      appBar: AppBar(
        title: const Text('Privacy & Security'),
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
            child: securityState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('Unable to load security settings.'),
              ),
              data: (state) => ListView(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'A safe space for your memories.',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add an extra layer of protection with a personal PIN '
                    'and biometric authentication.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Change PIN Card
                  _SecurityOptionCard(
                    icon: Icons.password_rounded,
                    title: 'Change PIN',
                    subtitle: 'Change your 4-digit app-lock PIN',
                    trailing: Icon(Icons.chevron_right),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                      bottom: Radius.circular(6),
                    ),
                    onTap: () {
                      // Navigate to Change PIN flow
                      context.push(Routes.changePin);
                    },
                  ),
                  const SizedBox(height: 3),

                  // Biometric Toggle Card
                  _SecurityOptionCard(
                    icon: Icons.fingerprint_rounded,
                    title: 'Enable Biometric Unlock',
                    subtitle: state.isBiometricAvailable
                        ? "Use your device's fingerprint or face recognition."
                        : 'Biometric authentication is unavailable on this device.',
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                      bottom: Radius.circular(18),
                    ),
                    trailing: Switch(
                      value: state.isBiometricEnabled,
                      onChanged: state.isBiometricAvailable
                          ? (value) => _handleBiometricToggle(
                                context,
                                ref,
                                value,
                              )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBiometricToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final error = await ref
        .read(privacySecurityViewModelProvider.notifier)
        .toggleBiometrics(value);

    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }
}

class _SecurityOptionCard extends StatelessWidget {
  const _SecurityOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.borderRadius,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final BorderRadius borderRadius;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: colors.onSurfaceVariant, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}