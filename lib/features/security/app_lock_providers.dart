import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

/// Tracks whether the current app session has passed the lock screen.
class AppLockSession extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;

  void lock() => state = false;
}

final appLockSessionProvider = NotifierProvider<AppLockSession, bool>(
  AppLockSession.new,
);
