import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/auth_provider.dart';

final registerViewModelProvider =
    AsyncNotifierProvider<RegisterViewmodel, void>(() {
      return RegisterViewmodel();
    });

class RegisterViewmodel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    return null;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.registerWithEmail(name, email, password);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }
}
