/// @file pin_verification_screen.dart
/// @description Authentication and user verification module.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutterapp/features/home/presentation/screens/home_screen.dart';
import 'package:flutterapp/features/auth/presentation/screens/login_screen.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/core/theme/app_colors.dart';

class PinVerificationScreen extends StatefulWidget {
  const PinVerificationScreen({super.key, required this.user});

  final AadhaarUser user;

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onPinDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyPin();
      }
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyPin() async {
    String enteredPin = _controllers.map((c) => c.text).join();
    if (enteredPin.length != 6) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final String? storedPin = prefs.getString('appPin');

    await Future.delayed(const Duration(milliseconds: 500));

    if (enteredPin == storedPin) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(user: widget.user)),
      );
    } else {
      setState(() {
        _isLoading = false;
        _error = "Incorrect PIN. Please try again.";
        for (var c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      });
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accent, Colors.white, AppColors.success],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Header
              Column(
                children: [
                   Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)
                      ],
                    ),
                    child: ClipOval(
                      child: widget.user.photoUrl != null && widget.user.photoUrl!.isNotEmpty
                          ? Image.network(widget.user.photoUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.person, size: 60, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome back, ${widget.user.name.split(' ')[0]}',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your 6-digit PIN to unlock',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 40,
                              height: 50,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                obscureText: true,
                                textAlign: TextAlign.center,
                                onChanged: (val) => _onPinDigitChanged(index, val),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  counterText: "",
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                                ),
                              ),
                            );
                          }),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                          ),
                        const SizedBox(height: 24), // Replaced Spacer
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          TextButton(
                            onPressed: _handleLogout,
                            child: Text("Switch User / Forgot PIN?", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
