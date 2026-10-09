import 'package:chronologe/core/utils/gradient_rotation_matrix.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../demo.dart';
import '../../shared/widgets/input_text_field.dart';
import 'register_viewmodel.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Field-specific inline error strings
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate on every keystroke for live validation
    _nameController.addListener(_validateInputsLive);
    _emailController.addListener(_validateInputsLive);
    _passwordController.addListener(_validateInputsLive);
    _confirmPasswordController.addListener(_validateInputsLive);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateInputsLive() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final emailValid = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);

    String? emailErr;
    String? passwordErr;
    String? confirmErr;

    // Validate email formatting
    if (email.isNotEmpty && !emailValid) {
      emailErr = "Please enter a valid email address.";
    }

    // Validate password length
    if (password.isNotEmpty && password.length < 6) {
      passwordErr = "Password must be at least 6 characters.";
    }

    // Validate password matching
    if (confirmPassword.isNotEmpty && password != confirmPassword) {
      confirmErr = "Passwords do not match.";
    }

    final isValid =
        name.isNotEmpty &&
        email.isNotEmpty &&
        emailValid &&
        password.length >= 6 &&
        password == confirmPassword;

    setState(() {
      _emailError = emailErr;
      _passwordError = passwordErr;
      _confirmPasswordError = confirmErr;
      _isFormValid = isValid;
    });
  }

  void _submitRegister() async {
    FocusScope.of(context).unfocus();

    final success = await ref
        .read(registerViewModelProvider.notifier)
        .register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      // Direct navigation to mandatory on-device PIN setup
      // context.go('/pin-setup');

    // TODO: demo only; remove this
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DemoWelcome()),
    );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorTheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final screenSize = MediaQuery.sizeOf(context);

    final registerState = ref.watch(registerViewModelProvider);
    final isProcessing = registerState.isLoading;

    ref.listen<AsyncValue<void>>(registerViewModelProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.toString(),
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
        },
      );
    });

    final canSubmit = _isFormValid && !isProcessing;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: screenSize.width,
            height: screenSize.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: colorTheme.surface,
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 0.05),
                    colors: [
                      colorTheme.surfaceContainerHighest,
                      colorTheme.surface,
                    ],
                    radius: 0.5,
                    stops: const [0.0, 0.524],
                    transform: const GradientRotationMatrix(),
                  ),
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
                  title: const Text("Register"),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Full Name",
                          style: textTheme.titleSmall!.copyWith(
                            color: colorTheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InputTextField(
                          controller: _nameController,
                          hintText: "e.g., Mahidhar Gowda",
                          keyboardType: TextInputType.name,
                          enabled: !isProcessing,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          "Email Address",
                          style: textTheme.titleSmall!.copyWith(
                            color: colorTheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InputTextField(
                          controller: _emailController,
                          hintText: "e.g., usermail@chronologe.com",
                          keyboardType: TextInputType.emailAddress,
                          enabled: !isProcessing,
                          hasError: _emailError != null,
                        ),
                        if (_emailError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _emailError!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorTheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        const SizedBox(height: 16),

                        Text(
                          "Password (min. 6 characters)",
                          style: textTheme.titleSmall!.copyWith(
                            color: colorTheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InputTextField(
                          controller: _passwordController,
                          hintText: "########",
                          isPassword: true,
                          enabled: !isProcessing,
                          hasError: _passwordError != null,
                        ),
                        if (_passwordError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _passwordError!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorTheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        const SizedBox(height: 16),

                        Text(
                          "Confirm Password",
                          style: textTheme.titleSmall!.copyWith(
                            color: colorTheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InputTextField(
                          controller: _confirmPasswordController,
                          hintText: "########",
                          isPassword: true,
                          enabled: !isProcessing,
                          hasError: _confirmPasswordError != null,
                        ),
                        if (_confirmPasswordError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _confirmPasswordError!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorTheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 54,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canSubmit ? _submitRegister : null,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("Sign Up"),
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: Text.rich(
                            textAlign: TextAlign.center,
                            TextSpan(
                              style: textTheme.bodyLarge,
                              children: [
                                const TextSpan(
                                  text: "Already have an account? ",
                                ),
                                TextSpan(
                                  text: "Login",
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.of(context).maybePop();
                                    },
                                  style: GoogleFonts.geist(
                                    color: colorTheme.primary,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: colorTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
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
