import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/repositories/auth_repository.dart';


final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    userDatabase: ref.read(userDatabaseProvider)
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});