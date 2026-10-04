import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_mode.dart';
import '../viewmodels/authentication_view_model.dart';

class AuthenticationPage extends ConsumerStatefulWidget {
  const AuthenticationPage({super.key});

  @override
  ConsumerState<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends ConsumerState<AuthenticationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authenticatedUserProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: user.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              const Center(child: Text('Your account could not be loaded.')),
          data: (user) => user == null
              ? _buildAuthenticationForm(context)
              : _buildSignedInAccount(context, user),
        ),
      ),
    );
  }

  Widget _buildAuthenticationForm(BuildContext context) {
    final authState = ref.watch(authenticationViewModelProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSignIn = authState.mode == AuthMode.signIn;

    return ListView(
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
              ? 'Sign in to sync and securely back up your diary.'
              : 'Register to sync and securely back up your diary.',
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
            ButtonSegment(value: AuthMode.register, label: Text('Register')),
          ],
          selected: {authState.mode},
          onSelectionChanged: authState.isLoading
              ? null
              : (selection) {
                  ref
                      .read(authenticationViewModelProvider.notifier)
                      .selectMode(selection.first);
                  _confirmPasswordController.clear();
                  _formKey.currentState?.reset();
                },
        ),
        const SizedBox(height: 20),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    enabled: !authState.isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    onChanged: (_) => ref
                        .read(authenticationViewModelProvider.notifier)
                        .clearError(),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !authState.isLoading,
                    obscureText: _hidePassword,
                    textInputAction: isSignIn
                        ? TextInputAction.done
                        : TextInputAction.next,
                    autofillHints: [
                      isSignIn
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onChanged: (_) => ref
                        .read(authenticationViewModelProvider.notifier)
                        .clearError(),
                    onFieldSubmitted: isSignIn ? (_) => _submit() : null,
                    validator: _validatePassword,
                  ),
                  if (!isSignIn) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      enabled: !authState.isLoading,
                      obscureText: _hideConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _hideConfirmPassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _hideConfirmPassword = !_hideConfirmPassword,
                          ),
                          icon: Icon(
                            _hideConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      onChanged: (_) => ref
                          .read(authenticationViewModelProvider.notifier)
                          .clearError(),
                      onFieldSubmitted: (_) => _submit(),
                      validator: _validateConfirmPassword,
                    ),
                  ],
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        authState.errorMessage!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: authState.isLoading ? null : _submit,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isSignIn ? 'Sign in' : 'Create account'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: authState.isLoading ? null : _signInWithGoogle,
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
                      label: const Text('Continue with Google'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedInAccount(BuildContext context, User user) {
    final authState = ref.watch(authenticationViewModelProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = user.displayName?.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        Center(
          child: CircleAvatar(
            radius: 42,
            foregroundImage: user.photoURL == null
                ? null
                : NetworkImage(user.photoURL!),
            backgroundColor: colors.primaryContainer,
            child: user.photoURL == null
                ? Icon(
                    Icons.person_outline_rounded,
                    size: 42,
                    color: colors.onPrimaryContainer,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          name == null || name.isEmpty ? 'Signed in' : name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        if (user.email != null)
          Text(
            user.email!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(
              user.emailVerified
                  ? Icons.verified_outlined
                  : Icons.info_outline_rounded,
            ),
            title: Text(
              user.emailVerified ? 'Email verified' : 'Email not verified',
            ),
            subtitle: Text(
              user.emailVerified
                  ? 'Your account is ready for future cloud backups.'
                  : 'Email verification can be added in the next step.',
            ),
          ),
        ),
        if (authState.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            authState.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.error),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: authState.isLoading ? null : _signOut,
          icon: authState.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (value.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your password.';
    if (value != _passwordController.text) return 'The passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(authenticationViewModelProvider.notifier);
    final mode = ref.read(authenticationViewModelProvider).mode;
    final success = mode == AuthMode.signIn
        ? await notifier.signIn(
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await notifier.register(
            email: _emailController.text,
            password: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
          );

    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mode == AuthMode.signIn
              ? 'Signed in successfully.'
              : 'Account created successfully.',
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    final success = await ref
        .read(authenticationViewModelProvider.notifier)
        .signInWithGoogle();
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Signed in with Google.')));
  }

  Future<void> _signOut() async {
    final signedOut = await ref
        .read(authenticationViewModelProvider.notifier)
        .signOut();
    if (!mounted || !signedOut) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
