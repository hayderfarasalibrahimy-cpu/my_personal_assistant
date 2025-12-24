import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// خدمة إدارة الأذونات
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// طلب جميع الأذونات اللازمة
  Future<bool> requestAllPermissions(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    List<Permission> permissions = [
      Permission.notification,
      Permission.scheduleExactAlarm,
    ];

    // طلب الأذونات
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // التحقق من النتائج
    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted && context.mounted) {
      // عرض رسالة للمستخدم
      _showPermissionDialog(context);
    }

    return allGranted;
  }

  /// طلب إذن الإشعارات
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// طلب إذن جدولة المنبهات الدقيقة
  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  /// طلب تجاهل تحسينات البطارية
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// التحقق من حالة الأذونات
  Future<Map<String, bool>> checkPermissions() async {
    return {
      'notifications': await Permission.notification.isGranted,
      'exactAlarm': await Permission.scheduleExactAlarm.isGranted,
      'batteryOptimization':
          await Permission.ignoreBatteryOptimizations.isGranted,
    };
  }

  /// عرض dialog لطلب الأذونات
  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('أذونات مطلوبة'),
          ],
        ),
        content: const Text(
          'لتعمل الإشعارات والمنبهات بشكل صحيح، يجب السماح للتطبيق بإرسال الإشعارات وجدولة المنبهات.\n\n'
          'يرجى منح الأذونات المطلوبة من إعدادات التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  /// فتح إعدادات التطبيق
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
