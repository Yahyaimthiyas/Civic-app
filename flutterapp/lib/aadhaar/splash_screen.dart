import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/aadhaar_api.dart';
import 'home_screen.dart';
import 'login_screen.dart';

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
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
        final String userId = prefs.getString('userId') ?? 'USER_123';
        final String userName = prefs.getString('userName') ?? 'User';
        
        // Reconstruct user object
        final user = AadhaarUser(
            id: userId,
            name: userName,
            aadhaarNumber: 'XXXX-XXXX-XXXX', // Placeholder until stored
            phoneNumber: '9876543210',       // Placeholder until stored
            dob: '01-01-1990', 
            gender: 'Male',
            address: 'Tamil Nadu',
            photoUrl: '',
        );

        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
        );
    } else {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
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
              Color(0xFFFF9933),
              Colors.white,
              Color(0xFF138808),
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
