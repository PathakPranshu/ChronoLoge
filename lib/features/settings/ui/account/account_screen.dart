
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/shared/providers/auth_provider.dart';
import 'account_viewmodel.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authState = ref.watch(authStateProvider);
    final signOutState = ref.watch(accountViewModelProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Account'),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: authState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => const Text(
                  'Unable to load account details.',
                ),
                data: (user) {
                  if (user == null) {
                    return const Text('No signed-in account found.');
                  }

                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: colors.primaryContainer,
                        backgroundImage: user.photoURL != null &&
                                user.photoURL!.isNotEmpty
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null ||
                                user.photoURL!.isEmpty
                            ? Icon(
                                Icons.person_outline,
                                size: 48,
                                color: colors.onPrimaryContainer,
                              )
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        user.displayName?.isNotEmpty == true
                            ? user.displayName!
                            : 'ChronoLoge user',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.email ?? 'No email available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.outlineVariant,
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.email_outlined,
                            color: colors.primary,
                          ),
                          title: const Text('Email address'),
                          subtitle: Text(
                            user.email ?? 'Not available',
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: signOutState.isLoading
                              ? null
                              : () => _confirmSignOut(context, ref),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in and set up your app security again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !context.mounted) return;

    try {
      await ref.read(accountViewModelProvider.notifier).signOut();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Please try again.'),
          ),
        );
      }
    }
  }
}
