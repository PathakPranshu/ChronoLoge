import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/authentication/shared/providers/auth_provider.dart';
import 'features/authentication/ui/login/login_screen.dart';

class DemoWelcome extends ConsumerWidget {
  const DemoWelcome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorTheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Watch the global authentication stream instead of calling Firebase directly
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: colorTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: colorTheme.error),
            tooltip: 'Sign Out',
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: authState.when(
            // When the stream is loading
            loading: () => const CircularProgressIndicator(),

            // When the stream has an error
            error: (error, stack) => Text("Error: $error"),

            // When the stream successfully emits a user (or null if signed out)
            data: (user) {
              if (user == null) {
                return const Text("Signing out...");
              }

              final displayName = user.displayName ?? "User";
              final email = user.email ?? "unknown email";

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Welcome, $displayName to ChronoLoge",
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorTheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "logged in as $email",
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorTheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
