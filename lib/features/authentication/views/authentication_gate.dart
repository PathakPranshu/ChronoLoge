import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/views/app_shell.dart';
import '../../tracking/viewmodels/background_tracking_controller.dart';
import '../viewmodels/authentication_view_model.dart';
import 'authentication_page.dart';

/// Shows sign-in when logged out and the real app when logged in.
class AuthenticationGate extends ConsumerWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authenticatedUserProvider);
    ref.listen(authenticatedUserProvider, (previous, next) {
      next.whenData((user) {
        if (previous?.value != null && user == null) {
          ref.invalidate(backgroundTrackingControllerProvider);
        }
      });
    });

    return user.when(
      loading: () => const _AuthenticationLoadingPage(),
      error: (error, stackTrace) => _AuthenticationErrorPage(
        onRetry: () => ref.invalidate(authenticatedUserProvider),
      ),
      data: (user) {
        if (user == null) return const AuthenticationPage();

        ref.watch(backgroundTrackingControllerProvider);
        return const AppShell();
      },
    );
  }
}

class _AuthenticationLoadingPage extends StatelessWidget {
  const _AuthenticationLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _AuthenticationErrorPage extends StatelessWidget {
  const _AuthenticationErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                const Text(
                  'Your account status could not be loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
