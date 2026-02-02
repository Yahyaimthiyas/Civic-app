import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pin_setup_screen.dart';
import 'services/aadhaar_api.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.aadhaarNumber,
    required this.maskedMobile,
    required this.phoneE164,
  });

  final String aadhaarNumber;
  final String maskedMobile;
  final String phoneE164;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String? _error;
  Timer? _timer;
  int _start = 59;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
            _canResend = true;
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _handleVerify() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() {
        _error = 'Please enter the 6-digit OTP.';
      });
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final response = await AadhaarApi.verifyOtp(widget.aadhaarNumber, otp);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(user: response.user),
        ),
      );
    } on AadhaarApiException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _resendOtp() async {
      setState(() {
          _isLoading = true;
          _error = null;
      });
      
      try {
          await AadhaarApi.sendOtp(widget.aadhaarNumber);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP sent successfully!')),
          );
          setState(() {
              _start = 59;
              _canResend = false;
          });
          startTimer();
      } catch (e) {
          setState(() {
              _error = 'Failed to resend OTP. Please try again.';
          });
      } finally {
          if (mounted) {
              setState(() {
                  _isLoading = false;
              });
          }
      }
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
        if (index > 0) {
            _focusNodes[index - 1].requestFocus();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      Icons.lock_person, // Key/Lock icon
                      color: Color(0xFFE6B000), // Gold/Yellow
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
                    _buildStep(1, "Aadhaar", true, isCompleted: true), // Completed
                    _buildStepLine(),
                    _buildStep(2, "Details", true), // Active
                    _buildStepLine(),
                    _buildStep(3, "Security", false),
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
                        color: Colors.black.withOpacity(0.05),
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
                          'OTP Verification',
                          style: TextStyle(
                             fontSize: 22,
                             fontWeight: FontWeight.bold,
                             color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                         Text(
                          'Enter the 6-digit code sent to',
                          style: const TextStyle(
                             fontSize: 14,
                             color: Colors.grey,
                             height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                            "XXXX-XXXX-XXXX",
                             style: TextStyle(
                                 color: Colors.green,
                                 fontWeight: FontWeight.bold,
                             ),
                             textAlign: TextAlign.center,
                        ),
                         const SizedBox(height: 32),
                        
                        // OTP Input
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                                return SizedBox(
                                    width: 45, // Increased width slightly
                                    height: 55, // Increased height slightly
                                    child: TextField(
                                        controller: _controllers[index],
                                        focusNode: _focusNodes[index],
                                        keyboardType: TextInputType.number,
                                        maxLength: 1,
                                        textAlign: TextAlign.center,
                                        onChanged: (val) => _onOtpDigitChanged(index, val),
                                        style: const TextStyle(
                                            fontSize: 22, 
                                            fontWeight: FontWeight.bold, 
                                            color: Colors.black
                                        ),
                                        decoration: InputDecoration(
                                            counterText: "",
                                            contentPadding: const EdgeInsets.symmetric(vertical: 8), // Adjusted padding
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
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 24),
                        
                        _canResend
                        ? TextButton(
                            onPressed: _isLoading ? null : _resendOtp,
                            child: const Text('Resend OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                        : Text(
                            "Resend OTP in 0:${_start.toString().padLeft(2, '0')}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                            ),
                        ),
                         const SizedBox(height: 16),
                        
                          ElevatedButton(
                          onPressed: _isLoading ? null : _handleVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8faec4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),

                        const SizedBox(height: 24),
                        
                        Container(
                           padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0), // Light Orange
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                                left: BorderSide(
                                    color: Colors.orange.shade700,
                                    width: 4,
                                )
                            )
                          ),
                           child: Row(
                            children: [
                               Icon(Icons.question_mark_rounded, color: Colors.red.shade400),
                               const SizedBox(width: 12),
                               const Expanded(
                                child: Text(
                                    "Didn't receive OTP? Check your SMS or try resending after the timer expires.",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                    ),
                                ),
                               )
                            ],
                           ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

   Widget _buildStep(int step, String label, bool isActive, {bool isCompleted = false}) {
      Color color = isCompleted ? const Color(0xFF22C55E) : (isActive ? const Color(0xFF22C55E) : Colors.grey.shade400); // Actually active is green too
      // Wait, in image "OTP Verify", 2 is circle filled with number, 1 is checkmark.
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
                       child: isCompleted 
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
          color: Colors.grey.shade300,
      );
  }
}
