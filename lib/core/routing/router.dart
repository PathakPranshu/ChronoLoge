import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../demo.dart';
import '../../features/authentication/shared/providers/auth_provider.dart';
import '../../features/authentication/shared/providers/secure_storage_provider.dart';
import '../../features/authentication/ui/login/login_screen.dart';
import '../../features/authentication/ui/register/register_screen.dart';
import '../../features/authentication/ui/security/views/pin_setup_screen.dart';
import '../../features/authentication/ui/security/views/unlock_screen.dart';
import 'router_provider.dart';
import 'routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) => _redirect(context, state, ref),
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.pinSetup,
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: Routes.unlock,
        builder: (context, state) => const UnlockScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const DemoWelcome(),
      ),
    ],
  );
});

Future<String?> _redirect(
  BuildContext context,
  GoRouterState state,
  Ref ref,
) async {
  final authState = ref.watch(authStateProvider);
  final isUnlocked = ref.watch(sessionUnlockedProvider);

  if (authState.isLoading) return null;

  final isLoggedIn = authState.value != null;
  final isAuthRoute =
      state.matchedLocation == Routes.login ||
      state.matchedLocation == Routes.register;

  if (!isLoggedIn) {
    return isAuthRoute ? null : Routes.login;
  }

  if (isLoggedIn) {
    final secureStorage = ref.read(secureStorageProvider);
    final hasPin = await secureStorage.hasPin();
    final settingPIN = state.matchedLocation == Routes.pinSetup;
    final unlocking = state.matchedLocation == Routes.unlock;

    // Must set up a PIN if they haven't
    if (!hasPin) {
      return settingPIN ? null : Routes.pinSetup;
    }

    // Must unlock the app if the session is locked
    if (!isUnlocked) {
      return unlocking? null: Routes.unlock;
    }

    if (isAuthRoute || settingPIN || unlocking) {
      return Routes.home;
    }
  }

  return null;
}
