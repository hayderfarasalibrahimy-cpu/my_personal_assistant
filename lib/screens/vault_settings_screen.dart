import 'package:flutter/material.dart';
import '../services/vault_service.dart';
import '../services/sound_service.dart';
import '../utils/app_snackbar.dart';

/// شاشة إعدادات الخزينة
class VaultSettingsScreen extends StatefulWidget {
  const VaultSettingsScreen({super.key});

  @override
  State<VaultSettingsScreen> createState() => _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends State<VaultSettingsScreen> {
  final VaultService _vaultService = VaultService();

  bool _isLoading = true;
  bool _hasPin = false;
  bool _hasBiometric = false;
  bool _canUseBiometric = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final hasPin = await _vaultService.hasPinSet();
    final hasBio = await _vaultService.isBiometricEnabled();
    final canUseBio = await _vaultService.canUseBiometrics();

    setState(() {
      _hasPin = hasPin;
      _hasBiometric = hasBio;
      _canUseBiometric = canUseBio;
      _isLoading = false;
    });
  }

  Future<void> _setPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعيين رمز PIN', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'رمز PIN (4 أرقام)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'تأكيد الرمز',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (pinController.text.length != 4) {
                AppSnackBar.error(context, 'الرمز يجب أن يكون 4 أرقام');
                return;
              }
              if (pinController.text != confirmController.text) {
                AppSnackBar.error(context, 'الرمزان غير متطابقين');
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _vaultService.setPin(pinController.text);
      SoundService.playSuccess();
      if (mounted) {
        AppSnackBar.success(context, 'تم تعيين رمز PIN بنجاح');
      }
      _loadSettings();
    }
  }

  Future<void> _removePinDialog() async {
    final pinController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة رمز PIN', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'أدخل الرمز الحالي',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final valid = await _vaultService.verifyPin(pinController.text);
              if (!valid) {
                if (context.mounted) {
                  AppSnackBar.error(context, 'رمز خاطئ');
                }
                return;
              }
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _vaultService.removePin();
      // إذا لم يعد هناك حماية، أغلق الحماية
      if (!await _vaultService.hasPinSet() &&
          !await _vaultService.isBiometricEnabled()) {
        await _vaultService.setProtectionEnabled(false);
      }
      SoundService.playSuccess();
      if (mounted) {
        AppSnackBar.success(context, 'تم إزالة الرمز');
      }
      _loadSettings();
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (enabled) {
      final success = await _vaultService.authenticateWithBiometrics();
      if (!success) {
        if (mounted) {
          AppSnackBar.error(context, 'فشل التحقق من البصمة');
        }
        return;
      }
    }

    await _vaultService.setBiometricEnabled(enabled);
    SoundService.playClick();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الخزينة', style: TextStyle(fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // عنوان قسم الحماية
                Text(
                  'حماية الخزينة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // PIN
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pin, color: Colors.blue),
                    ),
                    title: const Text('رمز PIN'),
                    subtitle: Text(
                      _hasPin ? 'مُفعّل' : 'غير مُفعّل',
                      style: TextStyle(
                        color: _hasPin ? Colors.green : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    trailing: _hasPin
                        ? TextButton(
                            onPressed: _removePinDialog,
                            child: const Text('إزالة'),
                          )
                        : FilledButton(
                            onPressed: _setPinDialog,
                            child: const Text('تعيين'),
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // البصمة
                if (_canUseBiometric)
                  Card(
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          color: Colors.green,
                        ),
                      ),
                      title: const Text('البصمة'),
                      subtitle: const Text(
                        'فتح الخزينة بالبصمة',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _hasBiometric,
                      onChanged: _toggleBiometric,
                    ),
                  ),

                const SizedBox(height: 24),

                // تحذير
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'إذا نسيت رمز PIN، لن تتمكن من الوصول للعناصر المخفية.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
