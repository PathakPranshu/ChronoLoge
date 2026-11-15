import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/gradient_rotation_matrix.dart';
import '../../authentication/shared/providers/auth_provider.dart';

enum TilePosition { first, middle, last, standalone }

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorTheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final screenSize = MediaQuery.sizeOf(context);

    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final userName = user?.displayName ?? 'User';
    final userEmail = user?.email ?? 'user@chronologe.app';
    final userPhotoUrl = user?.photoURL;
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: screenSize.width,
            height: screenSize.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: colorTheme.surface,
                  gradient: RadialGradient(
                    center: const Alignment(0.05, 0.05),
                    colors: [
                      colorTheme.primaryFixed.withValues(alpha: 0.2),
                      colorTheme.surface,
                    ],
                    radius: 0.5,
                    stops: const [0.0, 0.524],
                    transform: const GradientRotationMatrix(),
                  ),
                ),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              Theme(
                data: theme.copyWith(
                  textTheme: textTheme.copyWith(
                    headlineMedium: textTheme.displaySmall?.copyWith(
                      color: colorTheme.onSurface,
                    ),
                  ),
                ),
                child: const SliverAppBar.large(
                  automaticallyImplyLeading: false,
                  title: Text("Settings"),
                ),
              ),

              // Profile Card and First Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Touchable Profile Card
                      _ProfileCard(
                        name: userName,
                        email: userEmail,
                        initial: userInitial,
                        photoUrl: userPhotoUrl,
                        onTap: () {
                          context.push("account");
                        },
                      ),
                      const SizedBox(height: 32),

                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
                        child: Text(
                          "App Settings",
                          style: textTheme.titleSmall?.copyWith(
                            color: colorTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList.list(
                  children: [
                    _SettingsTile(
                      icon: Icons.tune_rounded,
                      iconColor: theme.colorScheme.onSecondaryFixedVariant,
                      iconBgColor: theme.colorScheme.secondaryFixedDim,
                      title: "Preferences",
                      subtitle: "Theme and diary appearance",
                      position: TilePosition.first,
                      onTap: () {
                        context.push("preferences");
                      },
                    ),
                    const SizedBox(height: 3),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      iconColor: theme.colorScheme.onTertiaryFixed,
                      iconBgColor: theme.colorScheme.tertiaryFixed,
                      title: "Notifications",
                      subtitle: "Daily reminders",
                      position: TilePosition.middle,
                      onTap: () {
                        context.push("notifications");

                      },
                    ),
                    const SizedBox(height: 3),
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      iconColor: theme.colorScheme.onTertiaryFixed,
                      iconBgColor: theme.colorScheme.tertiaryFixed,
                      title: "Privacy & Security",
                      subtitle: "App lock and Biometrics",
                      position: TilePosition.last,
                      onTap: () {
                        // TODO: Route to Privacy & Security
                      },
                    ),
                  ],
                ),
              ),

              // Second Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 16.0, 12.0),
                  child: Text(
                    "Diary & Info",
                    style: textTheme.titleSmall?.copyWith(
                      color: colorTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Diary & Info List (Optimized Lazy Loading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList.list(
                  children: [
                    _SettingsTile(
                      icon: Icons.auto_awesome,
                      iconColor: theme.colorScheme.onInverseSurface,
                      iconBgColor: theme.colorScheme.inverseSurface,
                      title: "Diary Generation",
                      subtitle: "Choose how your diary is created",
                      position: TilePosition.first,
                      onTap: () {
                        // TODO: Route to Diary Generation
                      },
                    ),
                    const SizedBox(height: 3),
                    _SettingsTile(
                      icon: Icons.backup_outlined,
                      iconColor: theme.colorScheme.onSecondaryFixedVariant,
                      iconBgColor: theme.colorScheme.secondaryFixedDim,
                      title: "Backup & Recovery",
                      subtitle: "Manage your diary backups",
                      position: TilePosition.middle,
                      onTap: () {
                        // TODO: Route to Backup & Recovery
                      },
                    ),
                    const SizedBox(height: 3),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: theme.colorScheme.onSecondaryFixedVariant,
                      iconBgColor: theme.colorScheme.secondaryFixedDim,
                      title: "App Info",
                      subtitle: "About ChronoLoge",
                      position: TilePosition.last,
                      onTap: () {
                        // TODO: Route to App Info
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          "ChronoLoge . Your days, remembered.",
                          style: textTheme.bodySmall?.copyWith(
                            color: colorTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Version 1.1.0-beta . JJSHH . Made with ❤️ at devlabs_",
                          style: textTheme.bodySmall?.copyWith(
                            color: colorTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  final String? photoUrl;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.initial,
    required this.onTap,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colorTheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Material(
      color: colorTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.deepPurple.shade600,
                backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
                child: !hasPhoto
                    ? Text(
                        initial,
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorTheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorTheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorTheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final TilePosition position;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorTheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    BorderRadius borderRadius;
    switch (position) {
      case TilePosition.first:
        borderRadius = const BorderRadius.vertical(
          top: Radius.circular(18),
          bottom: Radius.circular(8),
        );
        break;
      case TilePosition.last:
        borderRadius = const BorderRadius.vertical(
          top: Radius.circular(8),
          bottom: Radius.circular(18),
        );
        break;
      case TilePosition.middle:
        borderRadius = BorderRadius.circular(8);
        break;
      case TilePosition.standalone:
        borderRadius = BorderRadius.circular(18);
        break;
    }

    return Material(
      color: colorTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorTheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
