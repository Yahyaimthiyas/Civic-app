/// @file change_pin_screen.dart
/// @description Authentication and user verification module.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  int _step = 1; // 1: Old PIN, 2: New PIN, 3: Confirm PIN
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  String _oldPin = "";
  String _newPin = "";
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _handleNextStep();
      }
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleNextStep() async {
    String pin = _controllers.map((c) => c.text).join();
    if (pin.length != 6) return;

    if (_step == 1) {
      final prefs = await SharedPreferences.getInstance();
      final storedPin = prefs.getString('appPin');
      if (pin == storedPin) {
        setState(() {
          _oldPin = pin;
          _step = 2;
          _error = null;
          _clearInputs();
        });
      } else {
        setState(() {
          _error = "Old PIN is incorrect";
          _clearInputs();
        });
      }
    } else if (_step == 2) {
      setState(() {
        _newPin = pin;
        _step = 3;
        _error = null;
        _clearInputs();
      });
    } else if (_step == 3) {
      if (pin == _newPin) {
        _saveNewPin(pin);
      } else {
        setState(() {
          _error = "PINs do not match";
          _clearInputs();
        });
      }
    }
  }

  void _clearInputs() {
    for (var c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
  }

  Future<void> _saveNewPin(String pin) async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appPin', pin);
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PIN changed successfully"), backgroundColor: Colors.green),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String title = _step == 1 ? "Enter Old PIN" : (_step == 2 ? "Enter New PIN" : "Confirm New PIN");
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Change PIN", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF0B3D91).withValues(alpha: 0.05), shape: BoxShape.circle),
              child: const Icon(Icons.lock_reset_rounded, size: 64, color: Color(0xFF0B3D91)),
            ),
            const SizedBox(height: 32),
            Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Step $_step of 3", style: GoogleFonts.inter(color: Colors.grey)),
            const SizedBox(height: 40),
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
                    onChanged: (val) => _onDigitChanged(index, val),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: "",
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0B3D91), width: 2)),
                    ),
                  ),
                );
              }),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              const SizedBox(height: 20),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
