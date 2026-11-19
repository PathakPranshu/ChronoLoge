import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/section_heading.dart';
import 'account_viewmodel.dart';
import 'widgets/account_card.dart';
import 'widgets/account_text_field.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailCurrentPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _initializedFields = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _emailCurrentPasswordController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final appBarBackgroundColor = Color.alphaBlend(
      colors.surfaceTint.withValues(alpha: 0.1),
      colors.surfaceContainer,
    );

    final accountState = ref.watch(accountViewModelProvider);
    final isProcessing = accountState.isLoading;

    ref.listen<AsyncValue<AccountState>>(accountViewModelProvider, (_, next) {
      next.whenOrNull(
        error: (err, _) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err.toString())));
        },
      );
    });

    final data = accountState.value;
    if (data != null && !_initializedFields) {
      _nameController.text = data.displayName;
      _emailController.text = data.email;
      _initializedFields = true;
    }

    return Scaffold(
      backgroundColor: appBarBackgroundColor,
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
        // actions: [
        //   PopupMenuButton<String>(
        //     onSelected: (value) {
        //       if (value == 'delete' && data != null) {
        //         _showDeleteAccountDialog(context, data.isGoogleAuth);
        //       }
        //     },
        //     itemBuilder: (context) => [
        //       PopupMenuItem(
        //         value: 'delete',
        //         child: Row(
        //           children: [
        //             Icon(Icons.delete_outline, color: colors.error, size: 20),
        //             const SizedBox(width: 10),
        //             Text(
        //               'Delete Account',
        //               style: TextStyle(color: colors.error),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ],
        //   ),
        // ],
      ),
      body: Material(
        clipBehavior: Clip.antiAlias,
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: data == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  if (data.isGoogleAuth) ...[
                    const SectionHeading(
                      title: 'CONNECTED ACCOUNT',
                      subtitle: 'Signed in with Google',
                    ),
                    const SizedBox(height: 12),
                    _ConnectedEmailCard(email: data.email),
                    const SizedBox(height: 28),
                  ],

                  const SectionHeading(
                    title: 'DISPLAY NAME',
                    subtitle: 'How your name appears across ChronoLoge.',
                  ),
                  const SizedBox(height: 12),
                  AccountCard(
                    child: Column(
                      children: [
                        AccountTextField(
                          controller: _nameController,
                          enabled: !isProcessing,
                          labelText: 'Display name',
                          prefixIcon: Icons.person_outline,
                        ),
                        const Divider(height: 1),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: TextButton(
                              onPressed: isProcessing ? null : _handleSaveName,
                              child: const Text('Save Name'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Email & Password Updates (Only visible to non-Google- users)
                  if (!data.isGoogleAuth) ...[
                    const SizedBox(height: 28),
                    const SectionHeading(
                      title: 'EMAIL ADDRESS',
                      subtitle:
                          'A verification link will be sent to your new email.',
                    ),
                    const SizedBox(height: 12),
                    AccountCard(
                      child: Column(
                        children: [
                          AccountTextField(
                            controller: _emailController,
                            enabled: !isProcessing,
                            keyboardType: TextInputType.emailAddress,
                            labelText: 'New email address',
                            prefixIcon: Icons.email_outlined,
                          ),
                          const Divider(height: 1),
                          AccountTextField(
                            controller: _emailCurrentPasswordController,
                            enabled: !isProcessing,
                            isPassword: true,
                            labelText: 'Current password',
                            prefixIcon: Icons.lock_outline,
                          ),
                          const Divider(height: 1),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: TextButton(
                                onPressed: isProcessing
                                    ? null
                                    : _handleSaveEmail,
                                child: const Text('Update Email'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const SectionHeading(
                      title: 'CHANGE PASSWORD',
                      subtitle: 'Use at least 6 characters for your password.',
                    ),
                    const SizedBox(height: 12),
                    AccountCard(
                      child: Column(
                        children: [
                          AccountTextField(
                            controller: _currentPasswordController,
                            enabled: !isProcessing,
                            isPassword: true,
                            labelText: 'Current password',
                            prefixIcon: Icons.lock_outline,
                          ),
                          const Divider(height: 1),
                          AccountTextField(
                            controller: _newPasswordController,
                            enabled: !isProcessing,
                            isPassword: true,
                            labelText: 'New password',
                            prefixIcon: Icons.lock_reset_outlined,
                          ),
                          const Divider(height: 1),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: TextButton(
                                onPressed: isProcessing
                                    ? null
                                    : _handleSavePassword,
                                child: const Text('Update Password'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // Logout Button
                  OutlinedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            await ref
                                .read(accountViewModelProvider.notifier)
                                .signOut();
                          },
                    icon: Icon(Icons.logout_rounded, color: colors.error),
                    label: Text(
                      'Log Out',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: colors.error.withValues(alpha: 0.6)
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleSaveName() async {
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(accountViewModelProvider.notifier)
        .updateDisplayName(_nameController.text);

    if (success && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Display name updated.')));
    }
  }

  Future<void> _handleSaveEmail() async {
    FocusScope.of(context).unfocus();
    final newEmail = _emailController.text.trim();
    final password = _emailCurrentPasswordController.text;

    if (newEmail.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter both your new email and current password.',
          ),
        ),
      );
      return;
    }

    final success = await ref
        .read(accountViewModelProvider.notifier)
        .updateEmail(newEmail: newEmail, currentPassword: password);

    if (success && mounted) {
      _emailCurrentPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification link sent to your new email. It will update once verified.',
          ),
        ),
      );
    }
  }

  Future<void> _handleSavePassword() async {
    FocusScope.of(context).unfocus();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (currentPassword.isEmpty || newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your current password and a new password (min 6 characters).',
          ),
        ),
      );
      return;
    }

    final success = await ref
        .read(accountViewModelProvider.notifier)
        .updatePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );

    if (success && mounted) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    }
  }

  // Future<void> _showDeleteAccountDialog(
  //   BuildContext context,
  //   bool isGoogleAuth,
  // ) async {
  //   final passwordController = TextEditingController();

  //   await showDialog<void>(
  //     context: context,
  //     builder: (dialogContext) => AlertDialog(
  //       title: const Text('Delete Account?'),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text(
  //             'This action is permanent and will delete your account. '
  //             'Make sure you have backed up or downloaded your diary data first.',
  //           ),
  //           if (!isGoogleAuth) ...[
  //             const SizedBox(height: 16),
  //             TextField(
  //               controller: passwordController,
  //               obscureText: true,
  //               decoration: const InputDecoration(
  //                 labelText: 'Confirm with current password',
  //                 border: OutlineInputBorder(),
  //               ),
  //             ),
  //           ],
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(dialogContext),
  //           child: const Text('Cancel'),
  //         ),
  //         FilledButton(
  //           style: FilledButton.styleFrom(
  //             backgroundColor: Theme.of(context).colorScheme.error,
  //             foregroundColor: Theme.of(context).colorScheme.onError,
  //           ),
  //           onPressed: () async {
  //             Navigator.pop(dialogContext);
  //             await ref.read(accountViewModelProvider.notifier).deleteAccount(
  //                   currentPassword:
  //                       isGoogleAuth ? null : passwordController.text,
  //                 );
  //           },
  //           child: const Text('Delete'),
  //         ),
  //       ],
  //     ),
  //   );

  //   passwordController.dispose();
  // }
}

class _ConnectedEmailCard extends StatelessWidget {
  const _ConnectedEmailCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AccountCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset(
                "assets/images/google_icon.png",
                width: 20,
                height: 20,
                cacheHeight: 100,
                cacheWidth: 100,
              ),
            ),

            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Email & password are managed by Google',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
