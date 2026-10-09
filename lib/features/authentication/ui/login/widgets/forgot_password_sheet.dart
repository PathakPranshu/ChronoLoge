import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/input_text_field.dart';
import '../forgot_password_viewmodel.dart';

class ForgotPasswordSheet extends ConsumerStatefulWidget {
  const ForgotPasswordSheet({super.key});

  @override
  ConsumerState<ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  bool _isInputValid = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final email = _emailController.text;
    final emailValid = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);

    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    if (_isInputValid != emailValid) {
      setState(() {
        _isInputValid = emailValid;
      });
    }
  }

  void _submit() async {
    FocusScope.of(context).unfocus();

    final success = await ref
        .read(forgotPasswordViewModelProvider.notifier)
        .sendResetLink(_emailController.text);

    if (!mounted) return;

    if (success) {
      // Close the bottom sheet
      Navigator.pop(context);

      // Show a success message on the main login screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Password reset link sent to your email."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorTheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final forgotState = ref.watch(forgotPasswordViewModelProvider);
    final isProcessing = forgotState.isLoading;

    // Listen for errors
    ref.listen<AsyncValue<void>>(forgotPasswordViewModelProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, stackTrace) {
          setState(() {
            _errorMessage = error.toString();
          });
        },
      );
    });

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reset Password",
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your email address to receive a password reset link.",
            style: textTheme.bodyLarge?.copyWith(
              color: colorTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          InputTextField(
            controller: _emailController,
            hintText: "usermail@chronologe.com",
            keyboardType: TextInputType.emailAddress,
            enabled: !isProcessing,
          ),

          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: _isInputValid && !isProcessing ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: colorTheme.primary,
                foregroundColor: colorTheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: textTheme.bodyLarge,
              ),
              child: isProcessing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Send Reset Link"),
            ),
          ),
          const SizedBox(height: 32), // Bottom spacing
        ],
      ),
    );
  }
}
