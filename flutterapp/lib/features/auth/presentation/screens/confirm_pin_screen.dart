/// @file confirm_pin_screen.dart
/// @description Authentication and user verification module.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutterapp/features/home/presentation/screens/home_screen.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutterapp/core/theme/app_colors.dart';

class ConfirmPinScreen extends StatefulWidget {
  const ConfirmPinScreen({super.key, required this.user, required this.firstPin});

  final AadhaarUser user;
  final String firstPin;

  @override
  State<ConfirmPinScreen> createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends State<ConfirmPinScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
  
  void _onPinDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _handleConfirmPin();
      }
    } else {
        if (index > 0) {
            _focusNodes[index - 1].requestFocus();
        }
    }
  }

  Future<void> _handleConfirmPin() async {
    String confirmPin = _controllers.map((c) => c.text).join();
    if (confirmPin.length != 6) return;

    if (confirmPin != widget.firstPin) {
        setState(() {
            _error = "PINs do not match. Please try again.";
            // Clear controllers
            for(var c in _controllers) { c.clear(); }
            _focusNodes[0].requestFocus();
        });
        return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    // Save Session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    
    // Convert AadhaarUser to Map for JSON storage
    final userMap = {
      'id': widget.user.id,
      'fullName': widget.user.name,
      'aadhaarNumber': widget.user.aadhaarNumber,
      'mobile': widget.user.phoneNumber,
      'address': widget.user.address,
      'photoUrl': widget.user.photoUrl,
      'dob': widget.user.dob,
      'gender': widget.user.gender,
      'age': widget.user.age,
      'district': widget.user.district,
      'state': widget.user.state,
    };
    await prefs.setString('userJson', jsonEncode(userMap));
    await prefs.setString('appPin', confirmPin); // Save PIN for future logins

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(user: widget.user),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
               const SizedBox(height: 20),
              // Header
               Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                     child: const Icon(
                      Icons.security,
                      color: Color(0xFF607D8B),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tamil Nadu Digital Services', 
                     style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                   const SizedBox(height: 4),
                   const Text(
                    'Secure Registration Portal',
                     style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 24),

               // Steps Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStep(1, "Aadhaar", true, isCompleted: true),
                    _buildStepLine(),
                    _buildStep(2, "Details", true, isCompleted: true),
                    _buildStepLine(),
                    _buildStep(3, "Security", true, colorOverride: Colors.orange),
                  ],
                ),
              ),

               const SizedBox(height: 32),

              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                         const Text(
                          'Setup Security',
                          style: TextStyle(
                             fontSize: 22,
                             fontWeight: FontWeight.bold,
                             color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                         const Text(
                          'Confirm your 6-Digit PIN',
                          style: TextStyle(
                             fontSize: 14,
                             color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        
                        const Text(
                            "Confirm PIN",
                             style: TextStyle(
                                 fontSize: 18,
                                 fontWeight: FontWeight.bold,
                                 color: Colors.black87
                             ),
                             textAlign: TextAlign.center,
                        ),
                         const SizedBox(height: 16),
                        
                        // PIN Input
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                                return SizedBox(
                                    width: 45,
                                    height: 55,
                                    child: TextField(
                                        controller: _controllers[index],
                                        focusNode: _focusNodes[index],
                                        keyboardType: TextInputType.number,
                                        maxLength: 1,
                                        obscureText: true,
                                        textAlign: TextAlign.center,
                                        onChanged: (val) => _onPinDigitChanged(index, val),
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold
                                        ),
                                        decoration: InputDecoration(
                                            counterText: "",
                                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Colors.grey),
                                            ),
                                             focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Colors.blue),
                                            ),
                                        ),
                                    ),
                                );
                            }),
                        ),
                        
                        if (_error != null)
                             Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                             ),

                        const SizedBox(height: 24),

                         if (_isLoading)
                           const Center(child: CircularProgressIndicator())
                         else
                           const SizedBox(),

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

   Widget _buildStep(int step, String label, bool isActive, {bool isCompleted = false, Color? colorOverride}) {
      Color color = colorOverride ?? (isCompleted ? const Color(0xFF22C55E) : (isActive ? const Color(0xFF22C55E) : Colors.grey.shade400));
      return Column(
          children: [
               Container(
                   width: 32,
                   height: 32,
                   decoration: BoxDecoration(
                       color: color,
                       shape: BoxShape.circle,
                   ),
                   child: Center(
                       child: isCompleted && colorOverride == null
                       ? const Icon(Icons.check, color: Colors.white, size: 20)
                       : Text(
                           step.toString(),
                           style: const TextStyle(
                               color: Colors.white,
                               fontWeight: FontWeight.bold,
                           ),
                       ),
                   ),
               ),
               const SizedBox(height: 4),
               Text(
                   label,
                   style: TextStyle(
                       color: color,
                       fontWeight: FontWeight.bold,
                       fontSize: 12,
                   ),
               )
          ],
      );
  }

  Widget _buildStepLine() {
      return Container(
          width: 40,
          height: 2,
          margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4), 
          color: const Color(0xFF22C55E), // Completed line green
      );
  }
}
