import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/auth_provider.dart';

final forgotPasswordViewModelProvider =
    AsyncNotifierProvider<ForgotPasswordViewmodel, void>(() {
      return ForgotPasswordViewmodel();
    });

class ForgotPasswordViewmodel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state is idle
    return null;
  }

  Future<bool> sendResetLink(String email) async{
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.sendPasswordResetEmail(email);
      
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }
}
