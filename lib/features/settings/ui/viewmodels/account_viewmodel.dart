import 'dart:async';

import 'package:chronologe/core/routing/router_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/shared/providers/auth_provider.dart';

class AccountState {
  final String displayName;
  final String email;
  final bool isGoogleAuth;

  const AccountState({
    required this.displayName,
    required this.email,
    required this.isGoogleAuth,
  });

  AccountState copyWith({
    String? displayName,
    String? email,
    bool? isGoogleAuth,
  }) {
    return AccountState(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      isGoogleAuth: isGoogleAuth ?? this.isGoogleAuth,
    );
  }
}

final accountViewModelProvider =
    AsyncNotifierProvider<AccountViewModel, AccountState>(AccountViewModel.new);

class AccountViewModel extends AsyncNotifier<AccountState> {
  @override
  FutureOr<AccountState> build() {
    final user = ref.watch(userChangesProvider).value;
    final authRepo = ref.read(authRepositoryProvider);

    return AccountState(
      displayName: user?.displayName ?? '',
      email: user?.email ?? '',
      isGoogleAuth: authRepo.isGoogleAuthUser(),
    );
  }

  Future<bool> updateDisplayName(String newName) async {
    final current = state.value;
    final trimmed = newName.trim();
    if (current == null || trimmed.isEmpty || trimmed == current.displayName) {
      return false;
    }

    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(trimmed);
      state = AsyncData(current.copyWith(displayName: trimmed));
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current);
      return false;
    }
  }

  Future<bool> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final current = state.value;
    if (current == null || current.isGoogleAuth) return false;

    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .updateEmail(newEmail: newEmail, currentPassword: currentPassword);
      
      // TODO
      // Do not overwrite email yet; Firebase updates it after verification link is clicked

      state = AsyncData(current);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current);
      return false;
    }
  }

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = state.value;
    if (current == null || current.isGoogleAuth) return false;

    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = AsyncData(current);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current);
      return false;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    ref.read(sessionUnlockedProvider.notifier).lock();
  }

  Future<bool> deleteAccount({String? currentPassword}) async {
    final current = state.value;
    if (current == null) return false;

    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .deleteAccount(currentPassword: currentPassword);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current);
      return false;
    }
  }
}
