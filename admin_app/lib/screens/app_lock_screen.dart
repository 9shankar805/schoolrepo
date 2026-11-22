import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_security_service.dart';
import '../theme/app_theme.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({Key? key, required this.onUnlocked}) : super(key: key);

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final AppSecurityService _security = AppSecurityService();
  String _enteredPin = '';
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _verifyPin() {
    if (_security.unlockWithPin(_enteredPin)) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please re-enter.';
        _enteredPin = '';
      });
    }
  }

  void _simulateBiometricAuth() {
    // Immediate simulated biometric success for Principal device fingerprint/FaceID
    _security.unlockBiometricSuccess();
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                'Executive Security Lock',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Principal Command Center Protected',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.grey),
              ),
              const SizedBox(height: 28),

              // PIN Indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isFilled ? AppTheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: isFilled ? AppTheme.primary : Colors.white38, width: 2),
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.crimson, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],

              const Spacer(),

              // PIN Keypad
              Column(
                children: [
                  for (var row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((d) => _buildKey(d)).toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometric action
                        InkWell(
                          onTap: _simulateBiometricAuth,
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            width: 68,
                            height: 68,
                            alignment: Alignment.center,
                            child: const Icon(Icons.fingerprint_rounded, size: 34, color: AppTheme.primary),
                          ),
                        ),
                        _buildKey('0'),
                        // Backspace
                        InkWell(
                          onTap: _onBackspace,
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            width: 68,
                            height: 68,
                            alignment: Alignment.center,
                            child: const Icon(Icons.backspace_outlined, size: 24, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String digit) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}
