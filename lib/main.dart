import 'package:chronologe/core/themes/theme.dart';
import 'package:chronologe/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/authentication/ui/login/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(ProviderScope(child: const MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: CustomTheme.lightThemeData(context),
        darkTheme: CustomTheme.darkThemeData(context),
        home: LoginScreen(),
    );
  }
}

// JJSHH
// ChronoLoge Main App Dev : 30-09-2026
