import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/themes/theme_controller.dart';
import 'preferences_viewmodel.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedTheme = ref.watch(themeModeProvider);
    final diaryFontState = ref.watch(preferencesViewModelProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: const Text('Preferences'), pinned: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Make ChronoLoge feel like yours.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                _SectionHeading(
                  title: 'APPEARANCE',
                  subtitle: 'Choose how the app looks.',
                ),
                const SizedBox(height: 12),

                _PreferenceCard(
                  child: RadioGroup<ThemeMode>(
                    groupValue: selectedTheme,
                    onChanged: (mode) async {
                      if (mode == null) return;

                      try {
                        await ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(mode);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not save the appearance setting.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Column(
                      children: [
                        _ThemeOption(
                          title: 'System default',
                          subtitle: 'Follow your device settings',
                          value: ThemeMode.system,
                        ),
                        Divider(height: 1),
                        _ThemeOption(
                          title: 'Light',
                          subtitle: 'Always use light appearance',
                          value: ThemeMode.light,
                        ),
                        Divider(height: 1),
                        _ThemeOption(
                          title: 'Dark',
                          subtitle: 'Always use dark appearance',
                          value: ThemeMode.dark,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                _SectionHeading(
                  title: 'DIARY FONTS',
                  subtitle: 'Choose the typography for your diary entries.',
                ),
                const SizedBox(height: 12),

                diaryFontState.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, _) =>
                      const Text('Unable to load your diary font preference.'),
                  data: (selectedFont) => Column(
                    children: [
                      _DiaryFontOption(
                        title: 'Default',
                        description: 'Elegant and comfortable',
                        selected: selectedFont == DiaryFontStyle.fraunces,
                        onTap: () => _saveDiaryFont(
                          context,
                          ref,
                          DiaryFontStyle.fraunces,
                        ),
                        titleStyle: GoogleFonts.fraunces(
                          fontSize: 29,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        bodyStyle: GoogleFonts.geist(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DiaryFontOption(
                        title: 'Fancy',
                        description: 'Expressive and personal',
                        selected: selectedFont == DiaryFontStyle.literata,
                        onTap: () => _saveDiaryFont(
                          context,
                          ref,
                          DiaryFontStyle.literata,
                        ),
                        titleStyle: GoogleFonts.literata(
                          fontSize: 29,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        bodyStyle: GoogleFonts.comicNeue(
                          fontSize: 17,
                          height: 1.6,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  'Your selection will be used for diary content. '
                  'It does not change the rest of the app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDiaryFont(
    BuildContext context,
    WidgetRef ref,
    DiaryFontStyle font,
  ) async {
    try {
      await ref.read(preferencesViewModelProvider.notifier).setDiaryFont(font);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the diary font preference.'),
          ),
        );
      }
    }
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
    );
  }
}

class _DiaryFontOption extends StatelessWidget {
  const _DiaryFontOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.titleStyle,
    required this.bodyStyle,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle titleStyle;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.35)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A little moment from today', style: titleStyle),
                    const SizedBox(height: 6),
                    Text(
                      'Today was filled with little moments worth remembering. '
                      'I want to keep these memories close.',
                      style: bodyStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
