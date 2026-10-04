import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_mode.dart';

final authenticationViewModelProvider =
    NotifierProvider<AuthenticationViewModel, AuthMode>(
      AuthenticationViewModel.new,
    );

class AuthenticationViewModel extends Notifier<AuthMode> {
  @override
  AuthMode build() => AuthMode.signIn;

  void selectMode(AuthMode mode) => state = mode;
}
