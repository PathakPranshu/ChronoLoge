import 'package:chronologe/core/utils/gradient_rotation_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/routing/router_provider.dart';
import '../pin_setup_state.dart';
import '../viewmodels/pin_setup_viewmodel.dart';
import 'widgets/biometrics_setup_sheet.dart';
import 'widgets/numpad_widget.dart';
import 'widgets/pin_indicator.dart';

class PinSetupScreen extends ConsumerWidget {
  const PinSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorTheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final state = ref.watch(pinSetupViewModelProvider);
    final notifier = ref.read(pinSetupViewModelProvider.notifier);

    final isConfirmStep = state.step == PinSetupStep.confirm;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient matching standard app aesthetic
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colorTheme.surface,
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.05),
                  colors: [
                    colorTheme.secondaryFixedDim.withAlpha(100),
                    colorTheme.surface.withAlpha(50),
                  ],
                  radius: 0.5,
                  stops: const [0.0, 0.524],
                  transform: const GradientRotationMatrix(),
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
                    titleLarge: textTheme.titleLarge?.copyWith(
                      color: colorTheme.onSurface,
                    ),
                  ),
                ),
                child: SliverAppBar.large(
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConfirmStep ? "Confirm PIN" : "Secure Your Memories",
                      ),
                      const SizedBox(height: 8),
                      if (!isConfirmStep) ...[
                        Text(
                          "Create a PIN to lock the app",
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),

                      // The 4 Pin Dots
                      PinIndicator(
                        length: 4,
                        currentLength: state.currentInput.length,
                        hasError: state.hasError,
                      ),
                      const SizedBox(height: 20),

                      // Step Hint
                      Text(
                        state.hasError
                            ? state.errorMessage ?? ""
                            : isConfirmStep
                            ? "Re-enter your 4-digit PIN to confirm"
                            : "Enter a secure 4-digit PIN",
                        style: textTheme.titleSmall?.copyWith(
                          color: state.hasError
                              ? colorTheme.error
                              : colorTheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const Spacer(),

                      // Biometric Toggle Container (Only displayed during Confirm Step)
                      if (isConfirmStep && state.biometricsSupported) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorTheme.surfaceContainerLowest.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorTheme.outline.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Enable Biometric Unlock",
                                style: textTheme.titleSmall?.copyWith(
                                  color: colorTheme.onSurface,
                                ),
                              ),
                              Switch(
                                value: state.biometricsEnabled,
                                onChanged: (val) {
                                  if (val) {
                                    // Pop the Setup sheet
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) =>
                                          const BiometricsSetupSheet(),
                                    );
                                  } else {
                                    notifier.disableBiometrics();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        const SizedBox(height: 24),
                      ],

                      NumpadWidget(
                        onNumberTapped: notifier.addDigit,
                        onBackspaceTapped: notifier.removeDigit,
                      ),

                      const SizedBox(height: 32),

                      // Proceed Button (Disabled until PIN matches)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: state.isMatched && !state.isSaving
                              ? () async {
                                  final sessionNotifier = ref.read(
                                    sessionUnlockedProvider.notifier,
                                  );
                                  final success = await notifier
                                      .finalizeSetup();
                                  if (success) {
                                    print("sucess ${ref.read(sessionUnlockedProvider)}");
                                    sessionNotifier.unlock();
                                  }
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: colorTheme.primary,
                            foregroundColor: colorTheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: textTheme.bodyLarge,
                          ),
                          child: state.isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text("Proceed"),
                        ),
                      ),
                      const SizedBox(
                        height: 32,
                      ), // SafeArea bottom padding equivalent
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
