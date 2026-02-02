import 'package:flutter/material.dart';

import 'home_screen.dart';

class FingerprintEnableScreen extends StatelessWidget {
  const FingerprintEnableScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Enable Fingerprint'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0B3D91),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tamil Nadu Digital Services',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Secure Registration Portal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepCircle(
                          label: '1',
                          subtitle: 'Aadhaar',
                          color: const Color(0xFF22C55E),
                          showCheck: true,
                        ),
                        Container(
                          width: 40,
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: const Color(0xFF22C55E),
                        ),
                        _buildStepCircle(
                          label: '2',
                          subtitle: 'Details',
                          color: const Color(0xFF22C55E),
                          showCheck: true,
                        ),
                        Container(
                          width: 40,
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: const Color(0xFF22C55E),
                        ),
                        _buildStepCircle(
                          label: '3',
                          subtitle: 'Security',
                          color: const Color(0xFF22C55E),
                          showCheck: true,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Enable Fingerprint Login',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use your fingerprint for faster and secure access to your account.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.fingerprint,
                        size: 72,
                        color: Color(0xFF0B3D91),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Fingerprint data never leaves your device. We do not store your biometric information.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Fingerprint support will be fully enabled in a later version.',
                          ),
                        ),
                      );
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(user: user),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: const Color(0xFF22C55E),
                    ),
                    child: const Text(
                      'Enable Fingerprint and Continue',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(user: user),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCircle({
    required String label,
    required String subtitle,
    required Color color,
    bool showCheck = false,
  }) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: showCheck
                ? Icon(Icons.check, size: 18, color: color)
                : Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
