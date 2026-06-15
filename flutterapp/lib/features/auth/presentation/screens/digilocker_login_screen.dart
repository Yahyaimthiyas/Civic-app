/// @file digilocker_login_screen.dart
/// @description Authentication and user verification module.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:flutterapp/core/theme/app_colors.dart';
import 'package:flutterapp/features/home/presentation/screens/home_screen.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';

class DigiLockerLoginScreen extends StatefulWidget {
  const DigiLockerLoginScreen({super.key});

  @override
  State<DigiLockerLoginScreen> createState() => _DigiLockerLoginScreenState();
}

class _DigiLockerLoginScreenState extends State<DigiLockerLoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _otpSent = false;
  bool _isLoading = false;
  int _timer = 30;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = 30;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timer == 0) {
        timer.cancel();
      } else {
        setState(() {
          _timer--;
        });
      }
    });
  }

  void _sendOtp() {
    if (_mobileController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number or Aadhaar')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _otpSent = true;
      });
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to your registered mobile')),
      );
    });
  }

  void _verifyOtpAndLogin() {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate verification delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
      });
      _showConsentDialog();
    });
  }

  void _showConsentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/DigiLocker.svg/1200px-DigiLocker.svg.png',
                  height: 30,
                  errorBuilder: (c, o, s) => const Icon(Icons.lock, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Consent Request',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: Colors.black87, fontSize: 14, height: 1.5),
                children: const [
                  TextSpan(text: 'Application '),
                  TextSpan(
                    text: 'Tamil Nadu Civic App ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'is requesting access to your '),
                  TextSpan(
                    text: 'Aadhaar Card, Pan Card, and Driving License ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'from your DigiLocker account for verification purposes.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Deny', style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close sheet
                      _completeLogin();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF3B82F6),
                    ),
                    child: const Text('Allow', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _completeLogin() {
    // Navigate to Home Screen
    final mockUser = AadhaarUser(
        id: 'DIGILOCKER_USER_${DateTime.now().millisecondsSinceEpoch}',
        name: 'DigiLocker User',
        aadhaarNumber: 'XXXX-XXXX-XXXX',
        phoneNumber: _mobileController.text.isNotEmpty ? _mobileController.text : '9876543210',
        address: 'Chennai, Tamil Nadu',
        district: 'Chennai',
        state: 'Tamil Nadu',
        gender: 'Male',
        age: 25,
        photoUrl: null, 
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(user: mockUser)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('DigiLocker Sign In'),
        backgroundColor: const Color(0xFF3B82F6), // DigiLocker Blue
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // DigiLocker Logo Placeholder
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_sharp,
                size: 40,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to your account',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Access your authentic documents securely',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),

            if (!_otpSent) ...[
              // Step 1: Mobile/Username Input
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mobile / Aadhaar / Username',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mobileController,
                decoration: InputDecoration(
                  hintText: 'Enter your ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.perm_identity),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text(
                        'Sign In',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ] else ...[
              // Step 2: OTP Input
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter OTP sent to your mobile',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _otpController,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText: "",
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   Text(
                    _timer > 0 ? "Resend OTP in ${_timer}s" : "Resend OTP",
                    style: TextStyle(
                      color: _timer > 0 ? Colors.grey : const Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtpAndLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E), // Green for verify
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text(
                        'Submit',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ],

            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(onPressed: (){}, child: const Text('Sign Up', style: TextStyle(color: Color(0xFF3B82F6)))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
