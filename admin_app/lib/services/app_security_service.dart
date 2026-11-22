import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSecurityService with WidgetsBindingObserver {
  static final AppSecurityService _instance = AppSecurityService._internal();
  factory AppSecurityService() => _instance;

  AppSecurityService._internal();

  bool _isLockEnabled = false;
  bool _isLocked = false;
  String _storedPin = '1234'; // Default executive master PIN
  DateTime? _pausedTime;

  final ValueNotifier<bool> isLockedNotifier = ValueNotifier<bool>(false);

  // Configuration
  static const String _keyLockEnabled = 'sec_app_lock_enabled';
  static const String _keyPin = 'sec_master_pin';
  static const int _autoLockSeconds = 120; // 2 minutes background timeout

  bool get isLockEnabled => _isLockEnabled;
  bool get isLocked => _isLocked;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    _isLockEnabled = prefs.getBool(_keyLockEnabled) ?? false;
    _storedPin = prefs.getString(_keyPin) ?? '1234';

    if (_isLockEnabled) {
      _isLocked = true;
      isLockedNotifier.value = true;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    isLockedNotifier.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLockEnabled) return;

    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!).inSeconds;
        if (elapsed >= _autoLockSeconds) {
          lockApp();
        }
      }
      _pausedTime = null;
    }
  }

  void lockApp() {
    if (!_isLockEnabled) return;
    _isLocked = true;
    isLockedNotifier.value = true;
  }

  bool unlockWithPin(String pin) {
    if (pin == _storedPin) {
      _isLocked = false;
      isLockedNotifier.value = false;
      return true;
    }
    return false;
  }

  void unlockBiometricSuccess() {
    _isLocked = false;
    isLockedNotifier.value = false;
  }

  Future<void> setLockEnabled(bool enabled, {String? pin}) async {
    _isLockEnabled = enabled;
    if (pin != null && pin.isNotEmpty) {
      _storedPin = pin;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLockEnabled, enabled);
    if (pin != null) {
      await prefs.setString(_keyPin, pin);
    }
    if (!enabled) {
      _isLocked = false;
      isLockedNotifier.value = false;
    }
  }
}
