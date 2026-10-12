import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/pin_setup_viewmodel.dart';

class BiometricsSetupSheet extends ConsumerWidget {
  const BiometricsSetupSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorTheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final notifier = ref.read(pinSetupViewModelProvider.notifier);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: colorTheme.surface.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: colorTheme.outline.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: colorTheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),

              Icon(
                Icons.fingerprint_rounded,
                size: 64,
                color: colorTheme.primary,
              ),
              const SizedBox(height: 16),

              Text(
                "Setup Biometric Unlock",
                style: textTheme.headlineSmall?.copyWith(
                  color: colorTheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Verify your identity using your device's biometric sensor to enable quick unlock.",
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () async {
                    final success = await notifier.enableBiometrics();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Biometric verification failed.",
                              style: textTheme.bodyMedium!.copyWith(
                                color: colorTheme.onErrorContainer,
                              ),
                            ),
                            backgroundColor: colorTheme.errorContainer,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colorTheme.primary,
                    foregroundColor: colorTheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: textTheme.bodyLarge,
                  ),
                  child: const Text(
                    "Verify Identity",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
