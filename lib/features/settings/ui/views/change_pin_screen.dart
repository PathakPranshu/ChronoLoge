import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../authentication/ui/security/views/widgets/numpad_widget.dart';
import '../../../authentication/ui/security/views/widgets/pin_indicator.dart';
import '../viewmodels/change_pin_viewmodel.dart';

class ChangePinScreen extends ConsumerWidget {
  const ChangePinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final appBarBackgroundColor = Color.alphaBlend(
      colors.surfaceTint.withValues(alpha: 0.1),
      colors.surfaceContainer,
    );

    final state = ref.watch(changePinViewModelProvider);
    final notifier = ref.read(changePinViewModelProvider.notifier);

    ref.listen<ChangePinState>(changePinViewModelProvider, (prev, next) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated successfully.')),
        );
        context.pop();
      }
    });

    final (title, subtitle) = switch (state.step) {
      ChangePinStep.verifyCurrent => (
        'Enter Current PIN',
        'Verify your current 4-digit PIN to continue.',
      ),
      ChangePinStep.createNew => (
        'Enter New PIN',
        'Choose a new 4-digit PIN to lock your diary.',
      ),
      ChangePinStep.confirmNew => (
        'Confirm New PIN',
        'Re-enter your new 4-digit PIN to confirm.',
      ),
    };

    return Scaffold(
      backgroundColor: appBarBackgroundColor,
      appBar: AppBar(
        title: const Text('Change PIN'),
        backgroundColor: appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Material(
        clipBehavior: Clip.antiAlias,
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: colors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),

                PinIndicator(
                  currentLength: state.currentInput.length,
                  hasError: state.hasError,
                ),

                const SizedBox(height: 16),
                SizedBox(
                  height: 24,
                  child: state.errorMessage != null
                      ? Text(
                          state.errorMessage!,
                          textAlign: TextAlign.center,
                          style: textTheme.titleSmall?.copyWith(
                          color:colors.error
                        ))
                      : state.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),

                const Spacer(),

                NumpadWidget(
                  onNumberTapped: notifier.addDigit,
                  onBackspaceTapped: notifier.removeDigit,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}