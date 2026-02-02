import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'otp_verification_screen.dart';
import 'services/aadhaar_api.dart';

class AadhaarInputScreen extends StatefulWidget {
  const AadhaarInputScreen({super.key});

  @override
  State<AadhaarInputScreen> createState() => _AadhaarInputScreenState();
}

class _AadhaarInputScreenState extends State<AadhaarInputScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final raw = _controller.text.replaceAll(' ', '');
    // Basic validation
    if (raw.length != 12) {
         setState(() {
        _error = 'Please enter a valid 12-digit Aadhaar number';
      });
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final response = await AadhaarApi.sendOtp(raw);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            aadhaarNumber: raw,
            maskedMobile: response.maskedMobile,
            phoneE164: response.phoneE164,
          ),
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
                      Icons.account_balance,
                      color: Color(0xFF5F7C8A),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tamil Nadu Civic', 
                     style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                   const SizedBox(height: 4),
                   const Text(
                    'Secure Registration Portal',
                     style: TextStyle(
                      fontSize: 16,
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
                    _buildStep(1, "Aadhaar", true),
                    _buildStepLine(),
                    _buildStep(2, "Details", false),
                    _buildStepLine(),
                    _buildStep(3, "Security", false),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Card
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
                        Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0), // Purple
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "ID",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aadhaar Verification',
                          style: TextStyle(
                             fontSize: 22,
                             fontWeight: FontWeight.w700,
                             color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                         const Text(
                          'Enter your 12-digit Aadhaar number',
                          style: TextStyle(
                             fontSize: 15,
                             color: Color(0xFF78909C), // Blue Grey 400
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        
                        const Text(
                            "Aadhaar Number",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                fontSize: 14
                            ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFB0BEC5)), // Blue Grey 200
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFB0BEC5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                            errorText: _error,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF78909C), // Blue Grey 400 - Matches image better than 8194A5
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),

                        const SizedBox(height: 24),
                        
                        // Info Box
                        Container(
                             clipBehavior: Clip.antiAlias,
                             decoration: BoxDecoration(
                               color: const Color(0xFFE3F2FD),
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: IntrinsicHeight(
                               child: Row(
                                 children: [
                                   Container(
                                     width: 6,
                                     color: const Color(0xFF1976D2), // Darker Blue
                                   ),
                                   Expanded(
                                     child: Padding(
                                       padding: const EdgeInsets.all(16),
                                       child: Row(
                                         children: [
                                            Container(
                                               width: 24,
                                               height: 24,
                                               decoration: BoxDecoration(
                                                   color: const Color(0xFF78909C), // Matches button color
                                                   borderRadius: BorderRadius.circular(4),
                                               ),
                                               child: const Center(
                                                   child: Text(
                                                   'i',
                                                   style: TextStyle(
                                                       color: Colors.white,
                                                       fontWeight: FontWeight.bold,
                                                       fontFamily: 'serif',
                                                       fontSize: 16
                                                   ),
                                                   ),
                                               ),
                                            ),
                                           const SizedBox(width: 12),
                                           Expanded(
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 const Text(
                                                     "Secure & Private",
                                                     style: TextStyle(
                                                         color: Color(0xFF1976D2),
                                                         fontWeight: FontWeight.bold,
                                                         fontSize: 14
                                                     ),
                                                 ),
                                                 const SizedBox(height: 4),
                                                 const Text(
                                                     "Your Aadhaar details are encrypted and protected by government security standards.",
                                                     style: TextStyle(
                                                         color: Color(0xFF546E7A),
                                                         fontSize: 12,
                                                         height: 1.4
                                                     ),
                                                 ),
                                               ],
                                             ),
                                           )
                                         ],
                                       ),
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                        ),

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

  Widget _buildStep(int step, String label, bool isActive) {
      return Column(
          children: [
               Container(
                   width: 32,
                   height: 32,
                   decoration: BoxDecoration(
                       color: isActive ? const Color(0xFF00C853) : const Color(0xFFCFD8DC), // Brighter Green and BlueGrey Light
                       shape: BoxShape.circle,
                   ),
                   child: Center(
                       child: Text(
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
                       color: isActive ? const Color(0xFF00C853) : const Color(0xFFCFD8DC),
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
          margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4), // visually align with circle
          color: const Color(0xFFCFD8DC),
      );
  }
}
