import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/providers/theme_mode_provider.dart';
import '../../shared/diary_font_style.dart';
import '../../shared/providers/diary_font_provider.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appBarBackgroundColor = Color.alphaBlend(
      colors.surfaceTint.withValues(alpha: 0.075),
      colors.surfaceContainer,
    );
    final selectedTheme = ref.watch(themeModeProvider);
    final diaryFontState = ref.watch(preferencesViewModelProvider);

    return Scaffold(
      backgroundColor: appBarBackgroundColor,
      appBar: AppBar(
        title: const Text('Preferences'),
        backgroundColor: appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Material(
        clipBehavior: Clip.antiAlias,
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: RadialGradient(
                    center: AlignmentGeometry.directional(1, 3.5),
                    radius: 2,
                    colors: [
                      colors.primaryContainer.withRed(255),
                      colors.surfaceContainer,
                    ]
                  )
                ),
                child: Text(
                'Make \nChronoLoge feel like "yours".',
                style: GoogleFonts.literata(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: colors.onSurface,
                ),
              ),
              ),
              
              const SizedBox(height: 28),

              const _SectionHeading(
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

              const _SectionHeading(
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
                    _PreferenceCard(
                      child: Column(
                        children: [
                          _DiaryFontOption(
                            title: DiaryFontStyle.fraunces.label,
                            description: DiaryFontStyle.fraunces.description,
                            value: DiaryFontStyle.fraunces,
                            groupValue: selectedFont,
                            onChanged: (font) {
                              if (font != null){
                                _saveDiaryFont(context, ref, font);
                              }
                            },
                          ),
                          _DiaryFontOption(
                            title: DiaryFontStyle.literata.label,
                            description: DiaryFontStyle.literata.description,
                            value: DiaryFontStyle.literata,
                            groupValue: selectedFont,
                            onChanged: (font) {
                              if (font != null){
                                _saveDiaryFont(context, ref, font);}
                            },
                          ),
                          _DiaryFontOption(
                            title: DiaryFontStyle.instrument.label,
                            description: DiaryFontStyle.instrument.description,
                            value: DiaryFontStyle.instrument,
                            groupValue: selectedFont,
                            onChanged: (font) {
                              if (font != null){
                                _saveDiaryFont(context, ref, font);}
                            },
                          ),

                          Container(
                            margin: EdgeInsets.all(16),
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A little moment from today',
                                  style: selectedFont.titleStyle(
                                    TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Today was filled with little moments worth remembering. I want to keep these memories close.',
                                  style: selectedFont.bodyStyle(
                                    TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text(
                '* Your selection will be used for diary content. '
                'It does not change the rest of the app.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
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
            fontWeight: FontWeight.bold,
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
    return Material(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      value: value,
    );
  }
}

class _DiaryFontOption extends StatelessWidget {
  const _DiaryFontOption({
    required this.title,
    required this.description,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String description;
  final DiaryFontStyle value;
  final DiaryFontStyle groupValue;
  final ValueChanged<DiaryFontStyle?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<DiaryFontStyle>(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(description),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }
}
