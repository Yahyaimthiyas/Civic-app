/// @file splash_screen.dart
/// @description Authentication and user verification module.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/features/home/presentation/screens/home_screen.dart';
import 'package:flutterapp/features/auth/presentation/screens/login_screen.dart';
import 'package:flutterapp/features/auth/presentation/screens/pin_verification_screen.dart';
import 'package:flutterapp/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for animation/branding
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
        final String? userJson = prefs.getString('userJson');
        AadhaarUser user;
        
        if (userJson != null) {
            final userMap = jsonDecode(userJson) as Map<String, dynamic>;
            user = AadhaarUser.fromJson(userMap);
        } else {
            // Fallback for old sessions
            user = AadhaarUser(
                id: prefs.getString('userId') ?? 'USER_123',
                name: prefs.getString('userName') ?? 'User',
                aadhaarNumber: 'XXXX-XXXX-XXXX',
                phoneNumber: '9876543210',
            );
        }

        final String? appPin = prefs.getString('appPin');

        if (appPin != null && appPin.isNotEmpty) {
            // PIN is set -> Go to Verification
            if (mounted) {
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => PinVerificationScreen(user: user)),
              );
            }
        } else {
            // No PIN -> Go to Home directly (or force PIN setup if desired)
             if (mounted) {
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
              );
             }
        }
    } else {
         if (mounted) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
         }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent,
              Colors.white,
              AppColors.success,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance, size: 72, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Government of Tamil Nadu',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Digital Civic Services',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
