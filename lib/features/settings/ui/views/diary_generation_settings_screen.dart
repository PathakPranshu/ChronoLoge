import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/diary_generation_mode.dart';
import '../../shared/providers/diary_generation_settings_provider.dart';

class DiaryGenerationScreen extends ConsumerWidget {
  const DiaryGenerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final appBarBackgroundColor = Color.alphaBlend(
      colors.surfaceTint.withValues(alpha: 0.1),
      colors.surfaceContainer,
    );

    final generationState = ref.watch(diaryGenerationProvider);

    return Scaffold(
      backgroundColor: appBarBackgroundColor,
      appBar: AppBar(
        title: const Text('Diary Generation'),
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
            child: generationState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('Unable to load diary generation settings.'),
              ),
              data: (selectedMode) => ListView(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Your day, your story.',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how ChronoLoge turns your collected moments into a meaningful diary entry',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Material(
                    color: colors.surfaceContainerLow,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        _GenerationOptionTile(
                          mode: DiaryGenerationMode.automatic,
                          groupValue: selectedMode,
                          onSelected: () => _handleSelect(
                            context,
                            ref,
                            DiaryGenerationMode.automatic,
                          ),
                        ),
                        _GenerationOptionTile(
                          mode: DiaryGenerationMode.waitForInput,
                          groupValue: selectedMode,
                          onSelected: () => _handleSelect(
                            context,
                            ref,
                            DiaryGenerationMode.waitForInput,
                          ),
                        ),
                      ],
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

  Future<void> _handleSelect(
    BuildContext context,
    WidgetRef ref,
    DiaryGenerationMode mode,
  ) async {
    try {
      await ref.read(diaryGenerationProvider.notifier).setMode(mode);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update diary generation preference.'),
          ),
        );
      }
    }
  }
}

class _GenerationOptionTile extends StatelessWidget {
  const _GenerationOptionTile({
    required this.mode,
    required this.groupValue,
    required this.onSelected,
  });

  final DiaryGenerationMode mode;
  final DiaryGenerationMode groupValue;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: onSelected,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<DiaryGenerationMode>(
              value: mode,
              groupValue: groupValue,
              onChanged: (_) => onSelected(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}