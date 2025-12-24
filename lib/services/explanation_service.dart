import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExplanationService {
  static const String _prefix = 'explanation_';

  static Future<bool> shouldShow(String featureKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$featureKey') ?? true;
  }

  static Future<void> setDontShowAgain(String featureKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$featureKey', false);
  }

  static Future<void> showExplanationDialog({
    required BuildContext context,
    required String featureKey,
    required String title,
    required String explanation,
    required Future<void> Function() onProceed,
  }) async {
    final show = await shouldShow(featureKey);

    if (!show) {
      await onProceed();
      return;
    }

    bool dontShowAgain = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(explanation, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 15),
              CheckboxListTile(
                value: dontShowAgain,
                onChanged: (value) {
                  setState(() => dontShowAgain = value ?? false);
                },
                title: const Text(
                  'لا تظهر هذا الشرح مرة أخرى',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (dontShowAgain) {
                  await setDontShowAgain(featureKey);
                }
                if (context.mounted) Navigator.pop(context);
                await onProceed();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
  }
}
