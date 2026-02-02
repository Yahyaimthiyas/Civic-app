import 'package:flutter/material.dart';
import 'aadhaar_input_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF9933), // Saffron
              Colors.white,      // White
              Color(0xFF138808), // Green
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Header Section
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2ECC71), // Light Green circle bg
                    ),
                    child: const Icon(
                      Icons.account_balance, // Temple/Gov building icon
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tamil Nadu Civic',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Issue Reporting',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Secure Login Portal',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Card Section
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
                        color: Colors.black.withOpacity(0.1),
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
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose your preferred login method',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        
                        // Login with Aadhaar Button
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AadhaarInputScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E), // Green
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ID',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Login with Aadhaar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Login with DigiLocker Button
                        ElevatedButton(
                          onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('DigiLocker login coming soon')),
                              );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6), // Blue
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'Login with DigiLocker',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Divider
                         Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('or', style: TextStyle(color: Colors.grey)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Guest Login
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Guest login coming soon')),
                              );
                          },
                          icon: const Icon(Icons.person, color: Color(0xFF0F766E)), // Teal-ish
                          label: const Text(
                            'Continue as Guest',
                            style: TextStyle(
                              color: Color(0xFF0F766E),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        // Secured by Footer inside card
                         Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             Icon(Icons.lock_outline, size: 16, color: Colors.amber.shade700),
                             const SizedBox(width: 8),
                             const Text(
                              'Secured by Government of Jharkhand',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Bottom Footer
              Column(
                children: [
                   const Text(
                    'Digital India Initiative',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                   Text(
                    'Version 2.1.0',
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                   const SizedBox(height: 20),
                   Container(
                      width: 100,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26, 
                        borderRadius: BorderRadius.circular(2)
                      ),
                   )
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
