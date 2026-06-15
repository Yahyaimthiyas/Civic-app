import 'package:flutter/material.dart';
import 'package:flutterapp/features/auth/presentation/screens/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';

/// The entry point of the Civic application.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CivicApp());
}

/// The root widget of the Civic application.
///
/// Sets up the global theme and initial routing.
class CivicApp extends StatelessWidget {
  const CivicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civic App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
    );
  }
}

