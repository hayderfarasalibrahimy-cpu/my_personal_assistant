import 'package:flutter/material.dart';
import '../services/sound_service.dart';

/// أنواع الإشعارات
enum AppSnackBarType { success, error, warning, info }

/// خدمة موحدة لعرض الإشعارات داخل التطبيق
class AppSnackBar {
  /// عرض إشعار موحد
  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    bool playSound = true,
  }) {
    final (Color bgColor, Color iconColor, IconData icon) = switch (type) {
      AppSnackBarType.success => (
        Colors.green.shade700,
        Colors.white,
        Icons.check_circle_rounded,
      ),
      AppSnackBarType.error => (
        Colors.red.shade700,
        Colors.white,
        Icons.error_rounded,
      ),
      AppSnackBarType.warning => (
        Colors.orange.shade700,
        Colors.white,
        Icons.warning_rounded,
      ),
      AppSnackBarType.info => (
        Colors.blue.shade700,
        Colors.white,
        Icons.info_rounded,
      ),
    };

    // تشغيل الصوت والاهتزاز حسب نوع الإشعار
    if (playSound) {
      switch (type) {
        case AppSnackBarType.success:
          SoundService.playSuccess();
          break;
        case AppSnackBarType.error:
          SoundService.playError();
          break;
        case AppSnackBarType.warning:
          SoundService.playError(); // نفس صوت الخطأ للتحذير
          break;
        case AppSnackBarType.info:
          SoundService.playClick();
          break;
      }
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        action: action,
      ),
    );
  }

  static void showUndo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    String undoLabel = 'تراجع',
    AppSnackBarType type = AppSnackBarType.info,
    bool playSound = true,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final (Color bgColor, Color iconColor, IconData icon) = switch (type) {
      AppSnackBarType.success => (
        Colors.green.shade700,
        Colors.white,
        Icons.check_circle_rounded,
      ),
      AppSnackBarType.error => (
        Colors.red.shade700,
        Colors.white,
        Icons.error_rounded,
      ),
      AppSnackBarType.warning => (
        Colors.orange.shade700,
        Colors.white,
        Icons.warning_rounded,
      ),
      AppSnackBarType.info => (
        Colors.blue.shade700,
        Colors.white,
        Icons.info_rounded,
      ),
    };

    if (playSound) {
      switch (type) {
        case AppSnackBarType.success:
          SoundService.playSuccess();
          break;
        case AppSnackBarType.error:
          SoundService.playError();
          break;
        case AppSnackBarType.warning:
          SoundService.playError();
          break;
        case AppSnackBarType.info:
          SoundService.playClick();
          break;
      }
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onUndo();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(undoLabel),
            ),
            IconButton(
              onPressed: messenger.hideCurrentSnackBar,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: Colors.white,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'إغلاق',
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(days: 1),
      ),
    );
  }

  /// اختصارات للأنواع الشائعة
  static void success(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    bool playSound = true,
    Duration duration = const Duration(seconds: 3),
  }) => show(
    context,
    message: message,
    type: AppSnackBarType.success,
    action: action,
    playSound: playSound,
    duration: duration,
  );

  static void error(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    bool playSound = true,
    Duration duration = const Duration(seconds: 3),
  }) => show(
    context,
    message: message,
    type: AppSnackBarType.error,
    action: action,
    playSound: playSound,
    duration: duration,
  );

  static void warning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    bool playSound = true,
    Duration duration = const Duration(seconds: 3),
  }) => show(
    context,
    message: message,
    type: AppSnackBarType.warning,
    action: action,
    playSound: playSound,
    duration: duration,
  );

  static void info(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    bool playSound = true,
    Duration duration = const Duration(seconds: 3),
  }) => show(
    context,
    message: message,
    type: AppSnackBarType.info,
    action: action,
    playSound: playSound,
    duration: duration,
  );
}
