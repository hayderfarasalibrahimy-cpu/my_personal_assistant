import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vault_service.dart';
import '../services/sound_service.dart';

/// شاشة قفل الخزينة - إدخال PIN أو البصمة
class VaultLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const VaultLockScreen({super.key, required this.onUnlocked});

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> {
  final VaultService _vaultService = VaultService();
  final TextEditingController _pinController = TextEditingController();
  String _enteredPin = '';
  bool _isLoading = false;

  String? _errorMessage;
  VaultProtectionType _protectionType = VaultProtectionType.none;
  int _requiredPinLength = 4; // Default to 4 until loaded

  @override
  void initState() {
    super.initState();
    _loadProtectionType();
  }

  Future<void> _loadProtectionType() async {
    final type = await _vaultService.getProtectionType();
    final len = await _vaultService.getPinLength();
    setState(() {
      _protectionType = type;
      _requiredPinLength = len;
    });

    // محاولة فتح بالبصمة تلقائياً إذا كانت مُفعّلة
    if (type == VaultProtectionType.biometric) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    setState(() => _isLoading = true);
    final success = await _vaultService.authenticateWithBiometrics();
    setState(() => _isLoading = false);

    if (success) {
      _vaultService.unlock();
      widget.onUnlocked();
    }
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < _requiredPinLength) {
      SoundService.playClick();
      setState(() {
        _enteredPin += number;
        _errorMessage = null;
      });

      if (_enteredPin.length == _requiredPinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      SoundService.playClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    final success = await _vaultService.verifyPin(_enteredPin);
    setState(() => _isLoading = false);

    if (success) {
      SoundService.playSuccess();
      _vaultService.unlock();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'رمز خاطئ';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('الخزينة', style: TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // أيقونة القفل
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),

            // عنوان
            Text(
              'أدخل رمز الخزينة',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // رسالة الخطأ
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 14),
                ),
              ),

            const SizedBox(height: 24),

            // مؤشر PIN
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_requiredPinLength, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? theme.primaryColor
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const Spacer(),

            // لوحة الأرقام
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else
              _buildNumberPad(theme),

            // زر البصمة (إذا متاح)
            if (_protectionType == VaultProtectionType.biometric ||
                _protectionType == VaultProtectionType.pin)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('استخدم البصمة'),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad(ThemeData theme) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          children: [
            _buildNumberRow(['1', '2', '3'], theme),
            const SizedBox(height: 16),
            _buildNumberRow(['4', '5', '6'], theme),
            const SizedBox(height: 16),
            _buildNumberRow(['7', '8', '9'], theme),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 64), // فراغ
                _buildNumberButton('0', theme),
                _buildBackspaceButton(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(n, theme)).toList(),
    );
  }

  Widget _buildNumberButton(String number, ThemeData theme) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onBackspacePressed,
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
