import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/shared/providers/auth_provider.dart';

final accountViewModelProvider = AsyncNotifierProvider<AccountViewModel, void>(
  AccountViewModel.new,
);

class AccountViewModel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signOut() async {
    state = const AsyncLoading();

    try {
      await ref.read(authRepositoryProvider).signOut();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
