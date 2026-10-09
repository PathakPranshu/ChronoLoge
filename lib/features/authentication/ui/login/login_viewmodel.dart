import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/auth_provider.dart';

final loginViewModelProvider = AsyncNotifierProvider<LoginViewModel, void>(() {
  return LoginViewModel();
});

class LoginViewModel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state is idle (null data)
    return null;
  }

  Future<bool> loginWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      // Access the repository directly using the built-in 'ref'
      final repository = ref.read(authRepositoryProvider);
      await repository.signInWithEmailAndPassword(email, password);

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final signedIn = await repository.signInWithGoogle();

      state = const AsyncValue.data(null);
      return signedIn;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }
}
