import 'package:chronologe/core/utils/gradient_rotation_matrix.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../demo.dart';
import '../../shared/widgets/input_text_field.dart';
import '../register/register_screen.dart';
import 'login_viewmodel.dart';
import 'widgets/forgot_password_sheet.dart';
import 'widgets/google_signin_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isInputValid = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate button state on every keystroke
    _emailController.addListener(_validateInput);
    _passwordController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final email = _emailController.text;
    final password = _passwordController.text;

    // Standard email Regex
    final emailValid = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);

    final isValid = emailValid && password.isNotEmpty;
    if (_isInputValid != isValid) {
      setState(() {
        _isInputValid = isValid;
      });
    }
  }

  void _submitLogin() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final success = await ref
        .read(loginViewModelProvider.notifier)
        .loginWithEmail(_emailController.text, _passwordController.text);

    if (success) {
      _navigateToPinSetup();
    }
  }

  void _navigateToPinSetup() {
    if (!mounted) return;

    //Navigate to Pin setup
    //context.go('pin-setup');

    // TODO: demo only; remove this
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DemoWelcome()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Theme
    final theme = Theme.of(context);
    final colorTheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Watch the ViewModel for Loading States
    final loginState = ref.watch(loginViewModelProvider);
    final isProcessing = loginState.isLoading;

    // Listen to the ViewModel for Errors (Triggers once per error)
    ref.listen<AsyncValue<void>>(loginViewModelProvider, (previous, next) {
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

    final canSubmit = _isInputValid && !isProcessing;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          color: colorTheme.surface,
          gradient: RadialGradient(
            center: Alignment(0.0, 0.05),
            colors: [
              Color.alphaBlend(
                colorTheme.tertiaryContainer.withAlpha(200),
                colorTheme.surface,
              ),
              colorTheme.surface,
            ],
            radius: 0.5,
            stops: [0.0, 0.524],
            transform: GradientRotationMatrix(),
          ),
        ),
        child: CustomScrollView(
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
              child: SliverAppBar.large(leading: null, title: Text("Login")),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GoogleSignInButton(
                      isLoading: isProcessing,
                      onPressed: () async {
                        final success = await ref
                            .read(loginViewModelProvider.notifier)
                            .loginWithGoogle();

                        if (success) {
                          _navigateToPinSetup();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Divider(
                            color: colorTheme.outline,
                            thickness: 1,
                          ),
                        ),
                        Text(
                          "or use email, password",
                          style: textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: colorTheme.outline,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Enter your email",
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
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Password",
                            style: textTheme.titleSmall!.copyWith(
                              color: colorTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InputTextField(
                            controller: _passwordController,
                            hintText: "",
                            isPassword: true,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) =>
                                        const ForgotPasswordSheet(),
                                  );
                                },
                                child: Text("Forgot Password?"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 54,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: canSubmit ? _submitLogin : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorTheme.primary,
                                foregroundColor: colorTheme.onPrimary,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
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
                                  : Text("Login"),
                            ),
                          ),
                        ],
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
                            TextSpan(text: "New to ChronoLoge? "),
                            TextSpan(
                              text: "Create an Account!",
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // TODO: update navigation to use go_router
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RegisterScreen(),
                                    ),
                                  );
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
