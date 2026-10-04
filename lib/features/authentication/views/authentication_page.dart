import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_mode.dart';
import '../viewmodels/authentication_view_model.dart';

class AuthenticationPage extends ConsumerWidget {
  const AuthenticationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(authenticationViewModelProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSignIn = mode == AuthMode.signIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 34,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSignIn ? 'Welcome back' : 'Create your account',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSignIn
                  ? 'Sign in to prepare your diary for secure syncing and backups.'
                  : 'Register to prepare your diary for secure syncing and backups.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            SegmentedButton<AuthMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AuthMode.signIn, label: Text('Sign in')),
                ButtonSegment(
                  value: AuthMode.register,
                  label: Text('Register'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => ref
                  .read(authenticationViewModelProvider.notifier)
                  .selectMode(selection.first),
            ),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _showTemplateMessage(context),
                        icon: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            'G',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        label: Text(
                          isSignIn
                              ? 'Sign in with Google'
                              : 'Register with Google',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Google authentication is a prototype and is not connected yet.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google authentication will be connected later.'),
      ),
    );
  }
}
