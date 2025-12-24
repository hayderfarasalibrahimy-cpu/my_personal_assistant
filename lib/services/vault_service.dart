import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// خدمة الخزينة - إدارة الحماية والقفل
class VaultService {
  static final VaultService _instance = VaultService._internal();
  factory VaultService() => _instance;
  VaultService._internal();

  static const _keyVaultPin = 'vault_pin_hash';
  static const _keyVaultPinLength = 'vault_pin_length';
  static const _keyVaultPattern = 'vault_pattern_hash';
  static const _keyBiometricEnabled = 'vault_biometric_enabled';
  static const _keyVaultEnabled = 'vault_protection_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isUnlocked = false;

  /// هل الخزينة مفتوحة حالياً
  bool get isUnlocked => _isUnlocked;

  /// فتح الخزينة (بعد التحقق الناجح)
  void unlock() {
    _isUnlocked = true;
  }

  /// قفل الخزينة
  void lock() {
    _isUnlocked = false;
  }

  /// هل الحماية مُفعّلة
  Future<bool> isProtectionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVaultEnabled) ?? false;
  }

  /// تفعيل/تعطيل الحماية
  Future<void> setProtectionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVaultEnabled, enabled);
  }

  /// هل يوجد PIN مُعد
  Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVaultPin) != null;
  }

  /// هل يوجد نمط مُعد
  Future<bool> hasPatternSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVaultPattern) != null;
  }

  /// هل البصمة مُفعّلة
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// تعيين PIN جديد
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashString(pin);
    await prefs.setString(_keyVaultPin, hash);
    await prefs.setInt(_keyVaultPinLength, pin.length);
    await setProtectionEnabled(true);
  }

  /// التحقق من PIN
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_keyVaultPin);
    if (storedHash == null) return false;
    return storedHash == _hashString(pin);
  }

  /// إزالة PIN
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVaultPin);
    await prefs.remove(_keyVaultPinLength);
  }

  /// الحصول على طول PIN المخزن، افتراضياً 4
  Future<int> getPinLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVaultPinLength) ?? 4;
  }

  /// تعيين نمط جديد
  Future<void> setPattern(List<int> pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final patternString = pattern.join('-');
    final hash = _hashString(patternString);
    await prefs.setString(_keyVaultPattern, hash);
    await setProtectionEnabled(true);
  }

  /// التحقق من النمط
  Future<bool> verifyPattern(List<int> pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_keyVaultPattern);
    if (storedHash == null) return false;
    final patternString = pattern.join('-');
    return storedHash == _hashString(patternString);
  }

  /// إزالة النمط
  Future<void> removePattern() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVaultPattern);
  }

  /// تفعيل/تعطيل البصمة
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    if (enabled) {
      await setProtectionEnabled(true);
    }
  }

  /// هل الجهاز يدعم البصمة
  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  /// التحقق بالبصمة
  Future<bool> authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'التحقق للوصول للخزينة',
      );
      return authenticated;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  /// إزالة جميع إعدادات الحماية
  Future<void> clearAllProtection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVaultPin);
    await prefs.remove(_keyVaultPattern);
    await prefs.remove(_keyBiometricEnabled);
    await prefs.setBool(_keyVaultEnabled, false);
    _isUnlocked = false;
  }

  /// تشفير النص باستخدام SHA-256
  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// نوع الحماية المُعدة
  Future<VaultProtectionType> getProtectionType() async {
    if (await hasPinSet()) return VaultProtectionType.pin;
    if (await hasPatternSet()) return VaultProtectionType.pattern;
    if (await isBiometricEnabled()) return VaultProtectionType.biometric;
    return VaultProtectionType.none;
  }
}

enum VaultProtectionType { none, pin, pattern, biometric }
