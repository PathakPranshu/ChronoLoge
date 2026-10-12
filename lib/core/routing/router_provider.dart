import 'package:flutter_riverpod/flutter_riverpod.dart';


// Tracks if the user has successfully entered their PIN/Biometrics for this session
class SessionUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
  void lock() => state = false;
}

final sessionUnlockedProvider = NotifierProvider<SessionUnlockedNotifier, bool>(() {
  return SessionUnlockedNotifier();
});