import 'package:chronologe/core/utils/gradient_rotation_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/routing/router_provider.dart';
import '../unlock_state.dart';
import '../viewmodels/unlock_viewmodel.dart';
import 'widgets/numpad_widget.dart';
import 'widgets/pin_indicator.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  bool _hasPromptedBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptBiometrics();
    });
  }

  Future<void> _checkAndPromptBiometrics() async {
    final notifier = ref.read(unlockViewModelProvider.notifier);
    await Future.delayed(const Duration(milliseconds: 100)); 
    
    final state = ref.read(unlockViewModelProvider);
    
    if (state.biometricsEnabled && !_hasPromptedBiometrics) {
      _hasPromptedBiometrics = true;
      final unlocked = await notifier.promptBiometrics();
      
      if (unlocked && mounted) {
        _navigateToApp();
      }
    }
  }

  void _navigateToApp() {
    ref.read(sessionUnlockedProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorTheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final state = ref.watch(unlockViewModelProvider);
    final notifier = ref.read(unlockViewModelProvider.notifier);

    // Listen strictly for the isUnlocked success flag
    ref.listen<UnlockState>(unlockViewModelProvider, (previous, next) {
      if (previous?.isUnlocked == false && next.isUnlocked == true) {
        _navigateToApp();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient matching standard app aesthetic
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colorTheme.surface,
                gradient: RadialGradient(
                  center: const Alignment(-0.05, 0.05),
                  colors: [
                    colorTheme.secondaryFixed.withAlpha(100),
                    colorTheme.surface.withAlpha(20),
                  ],
                  radius: 0.5,
                  stops: const [0.009, 0.524],
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
                    headlineMedium: textTheme.displaySmall?.copyWith(color: colorTheme.onSurface),
                    titleLarge: textTheme.titleLarge?.copyWith(color: colorTheme.onSurface),
                  ),
                ),
                child: SliverAppBar.large(
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hi, ${state.userName}"),
                      const SizedBox(height: 8),
                      Text(
                        "Unlock the app to view your memories",
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorTheme.onSurfaceVariant,
                        ),
                      ),
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
                      
                      // Status Hint
                      Text(
                        state.hasError ? "Incorrect PIN" : "Enter your 4-digit PIN",
                        style: textTheme.titleSmall?.copyWith(
                          color: state.hasError ? colorTheme.error : colorTheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const Spacer(),

                      // Biometric Trigger Text (Only visible if enabled)
                      if (state.biometricsEnabled) ...[
                        TextButton(
                          onPressed: () async {
                            final unlocked = await notifier.promptBiometrics();
                            if (unlocked && context.mounted) {
                              _navigateToApp();
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: colorTheme.primary, 
                          ),
                          child: const Text(
                            "Use Biometrics to unlock",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Numpad (Bottom left empty intentionally)
                      NumpadWidget(
                        onNumberTapped: notifier.addDigit,
                        onBackspaceTapped: notifier.removeDigit,
                        hasBiometrics: false, 
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Footer Encryption Notice
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 20,
                            color: colorTheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "All data is securely encrypted.",
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32), // SafeArea bottom padding equivalent
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