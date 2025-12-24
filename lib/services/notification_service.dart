import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../services/database_service.dart';
import '../main.dart';
import 'alarm_service.dart';

/// خدمة الإشعارات المحلية
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // إعدادات الإشعارات
  static bool _notificationsEnabled = true;
  static bool _taskRemindersEnabled = true;
  static bool _aiNotificationsEnabled = true;

  // Getters
  static bool get notificationsEnabled => _notificationsEnabled;
  static bool get taskRemindersEnabled => _taskRemindersEnabled;
  static bool get aiNotificationsEnabled => _aiNotificationsEnabled;

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint('Initializing NotificationService...');

    // تهيئة المنطقة الزمنية
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Timezone: Using device timezone ($timeZoneName)');
    } catch (e) {
      // fallback آمن
      tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
      debugPrint('Timezone: Fallback to Asia/Baghdad ($e)');
    }

    // إعدادات Android
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // إعدادات iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // طلب الأذونات على Android 13+
    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
    }

    // تحميل الإعدادات
    await loadSettings();

    _isInitialized = true;
  }

  Future<void> _requestAndroidPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      // طلب إذن الإشعارات
      final notificationGranted = await androidPlugin
          .requestNotificationsPermission();
      debugPrint('إذن الإشعارات: $notificationGranted');

      // طلب إذن المنبهات الدقيقة (مطلوب في Android 12+)
      if (await Permission.scheduleExactAlarm.isDenied) {
        debugPrint('طلب إذن جدولة المنبهات الدقيقة...');
        await Permission.scheduleExactAlarm.request();
      }

      final exactAlarmGranted = await androidPlugin
          .requestExactAlarmsPermission();
      debugPrint('إذن المنبهات الدقيقة (Plugin): $exactAlarmGranted');

      // التحقق من تحسين البطارية
      await requestIgnoreBatteryOptimizations();
    }
  }

  /// طلب تجاهل تحسين البطارية لضمان عمل المنبه في الخلفية
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (Platform.isAndroid) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      debugPrint('حالة تحسين البطارية: $status');

      if (!status.isGranted) {
        debugPrint('طلب تجاهل تحسين البطارية...');
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  void _onNotificationTap(NotificationResponse response) async {
    // التعامل مع النقر على الإشعار
    debugPrint(
      'تم النقر على الإشعار: ${response.payload} (Action: ${response.actionId})',
    );

    // إذا كان إشعار منبه، أو تم النقر على إيقاف
    if (response.payload == 'alarm' || response.actionId == 'stop_alarm') {
      _stopAlarmSound();
    }

    // التعامل مع أزرار المهام
    if (response.payload != null && response.payload!.startsWith('task:')) {
      final taskId = response.payload!.split(':')[1];

      if (response.actionId == 'done_task') {
        debugPrint('تم تحديد المهمة كمكتملة من الإشعار: $taskId');
        try {
          final db = DatabaseService();
          final task = await db.getTaskById(taskId);
          if (task != null) {
            final now = DateTime.now();
            await db.updateTask(
              task.copyWith(
                isCompleted: true,
                completedAt: now,
                updatedAt: now,
              ),
            );
            debugPrint('تم تحديث المهمة في قاعدة البيانات بنجاح');
            _stopAlarmSound();

            // تحديث واجهة المستخدم إذا كان التطبيق مفتوحاً
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              try {
                Provider.of<TaskProvider>(
                  context,
                  listen: false,
                ).loadTasks(showLoading: false);
              } catch (e) {
                debugPrint('فشل تحديث Provider: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('خطأ في إكمال المهمة من الإشعار: $e');
        }
      }

      if (response.actionId == 'snooze_10') {
        debugPrint('طلب تأجيل المهمة 10 دقائق: $taskId');
        try {
          _stopAlarmSound();
          final db = DatabaseService();
          final task = await db.getTaskById(taskId);
          if (task != null) {
            final snoozeTime = DateTime.now().add(const Duration(minutes: 10));

            // تحديث وقت التذكير في قاعدة البيانات ليعكس التأجيل في الواجهة
            await db.updateTask(
              task.copyWith(
                reminderTime: snoozeTime,
                updatedAt: DateTime.now(),
              ),
            );

            // جدولة التنبيه الجديد
            await AlarmService().scheduleAlarmAfter(
              duration: const Duration(minutes: 10),
              title: task.title,
              body: 'تأجيل التنبيه لـ 10 دقائق ⏱️',
              taskId: task.id,
              priority: task.priority,
            );
            debugPrint('تم تحديث المهمة وجدولة التأجيل لـ 10 دقائق بنجاح');

            // تحديث واجهة المستخدم إذا كان التطبيق مفتوحاً
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              try {
                Provider.of<TaskProvider>(
                  context,
                  listen: false,
                ).loadTasks(showLoading: false);
              } catch (e) {
                debugPrint('فشل تحديث Provider: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('خطأ في تأجيل المهمة من الإشعار: $e');
        }
      }
    }
  }

  /// إيقاف صوت المنبه
  void _stopAlarmSound() {
    try {
      AlarmService().stopAlarm();
      debugPrint('تم إيقاف صوت المنبه بنجاح');
    } catch (e) {
      debugPrint('خطأ في إيقاف المنبه: $e');
    }
  }

  /// توليد معرف رقمي من معرف نصي (String ID)
  static int getNotificationId(String stringId) {
    // استخدم hashCode وتأكد من أنه في نطاق 32 بت (موجب)
    return (stringId.hashCode & 0x7FFFFFFF) % 1000000;
  }

  /// تحويل مسار ملف الصوت من assets إلى اسم مورد Android (بدون امتداد)
  static String? getResourceIdFromAsset(String? assetPath) {
    if (assetPath == null) return null;

    // خريطة التحويل للأصوات المخصصة التي قمنا بنسخها
    const soundMap = {
      'assets/sounds/alarms/2krSI3xEUiU.mp3': 'alarm_calm_1',
      'assets/sounds/alarms/LjWRjGpyaXg.mp3': 'alarm_calm_2',
      'assets/sounds/alarms/k-Rph1QwvMk.mp3': 'alarm_calm_3',
      'assets/sounds/alarms/nSVHb-eem1k.mp3': 'alarm_calm_4',
      'assets/sounds/alarms/pA1sX3Usxcw.mp3': 'alarm_calm_5',
      'assets/sounds/alarms/qTAxER4SiEA.mp3': 'alarm_calm_6',
      'assets/sounds/alarms/alarm_ding.mp3': 'alarm_ding',
      'assets/sounds/alarms/alarm_gentle.mp3': 'alarm_gentle',
      'assets/sounds/alarms/alarm_light.mp3': 'alarm_light',
      'assets/sounds/alarms/alarm_notification.mp3': 'alarm_notification',
      'assets/sounds/alarms/alarm_ringtone.mp3': 'alarm_ringtone',
      'assets/sounds/alarms/alarm_simple.mp3': 'alarm_simple',
      'assets/sounds/alarms/alarm_soft_ding.mp3': 'alarm_soft_ding',
    };

    return soundMap[assetPath];
  }

  /// تحميل الإعدادات
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _taskRemindersEnabled = prefs.getBool('task_reminders_enabled') ?? true;
    _aiNotificationsEnabled = prefs.getBool('ai_notifications_enabled') ?? true;
  }

  /// حفظ الإعدادات
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('task_reminders_enabled', _taskRemindersEnabled);
    await prefs.setBool('ai_notifications_enabled', _aiNotificationsEnabled);
  }

  /// تعيين إعدادات الإشعارات
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await saveSettings();
  }

  Future<void> setTaskRemindersEnabled(bool value) async {
    _taskRemindersEnabled = value;
    await saveSettings();
  }

  Future<void> setAiNotificationsEnabled(bool value) async {
    _aiNotificationsEnabled = value;
    await saveSettings();
  }

  /// إرسال إشعار فوري
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
    String? soundPath,
  }) async {
    // التأكد من تهيئة الخدمة
    if (!_isInitialized) {
      await initialize();
    }

    final resourceName = getResourceIdFromAsset(soundPath);
    // استخدام معرف قناة ديناميكي لضمان تطبيق إعدادات الصوت والأولوية لكل صوت
    final channelId = resourceName != null
        ? 'general_channel_$resourceName'
        : 'general_channel_v3';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'إشعارات عامة',
      channelDescription: 'إشعارات مذكرة الحياة الهامة',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: resourceName != null
          ? RawResourceAndroidNotificationSound(resourceName)
          : null,
      enableVibration: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'stop_alarm',
          'إيقاف المنبه ⏹️',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('خطأ في إرسال الإشعار: $e');
    }
  }

  /// إشعار من الذكاء الاصطناعي
  Future<void> showAiNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_notificationsEnabled || !_aiNotificationsEnabled) return;

    final androidDetails = AndroidNotificationDetails(
      'ai_channel_v3',
      'إشعارات المساعد الذكي',
      channelDescription: 'إشعارات من المساعد الذكي',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: const Color(0xFF2196F3),
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '🤖 $title',
        summaryText: 'رسالة من المساعد الذكي',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🤖 $title',
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showTaskReminder({
    required String taskTitle,
    required String taskDescription,
    required int taskId,
    String? soundPath,
  }) async {
    if (!_notificationsEnabled || !_taskRemindersEnabled) return;

    final resourceName = getResourceIdFromAsset(soundPath);
    final channelId = resourceName != null
        ? 'task_channel_$resourceName'
        : 'task_channel_v3';

    final fullTitle = '📋 $taskTitle';
    final fullBody = taskDescription.isNotEmpty
        ? taskDescription
        : 'حان وقت هذه المهمة! 🚀';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'تذكيرات المهام',
      channelDescription: 'تذكيرات المهام المجدولة الهامة',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: resourceName != null
          ? RawResourceAndroidNotificationSound(resourceName)
          : null,
      enableVibration: true,
      color: const Color(0xFF4CAF50),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(
        fullBody,
        contentTitle: fullTitle,
        summaryText: 'مساعدك الشخصي',
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'done_task',
          'تم الإنجاز ✅',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'snooze_10',
          'تأجيل 10 دقائق ⏱️',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      taskId,
      fullTitle,
      fullBody,
      details,
      payload: 'task:$taskId',
    );
  }

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required String taskDescription,
    required DateTime scheduledTime,
    String? soundPath,
    String repeatType = 'none',
    List<int>? repeatDays,
  }) async {
    final intId = getNotificationId(taskId);
    final now = DateTime.now();
    var effectiveScheduledTime = scheduledTime;

    if (repeatType != 'none' && effectiveScheduledTime.isBefore(now)) {
      if (repeatType == 'daily') {
        while (effectiveScheduledTime.isBefore(now)) {
          effectiveScheduledTime = effectiveScheduledTime.add(
            const Duration(days: 1),
          );
        }
      } else if (repeatType == 'weekly') {
        while (effectiveScheduledTime.isBefore(now)) {
          effectiveScheduledTime = effectiveScheduledTime.add(
            const Duration(days: 7),
          );
        }
      } else if (repeatType == 'weekdays') {
        while (effectiveScheduledTime.isBefore(now) ||
            (effectiveScheduledTime.weekday == 6 ||
                effectiveScheduledTime.weekday == 7)) {
          effectiveScheduledTime = effectiveScheduledTime.add(
            const Duration(days: 1),
          );
        }
      }
    }

    if (!_notificationsEnabled || !_taskRemindersEnabled) return;

    final resourceName = getResourceIdFromAsset(soundPath);
    final channelId = resourceName != null
        ? 'task_channel_$resourceName'
        : 'task_channel_v3';

    final fullTitle = '📋 $taskTitle';
    final fullBody = taskDescription.isNotEmpty
        ? taskDescription
        : 'حان وقت هذه المهمة! 🚀';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'تذكيرات المهام',
      channelDescription: 'تذكيرات المهام المجدولة الهامة',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: resourceName != null
          ? RawResourceAndroidNotificationSound(resourceName)
          : null,
      enableVibration: true,
      color: const Color(0xFF4CAF50),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(
        fullBody,
        contentTitle: fullTitle,
        summaryText: 'تذكير مجدول',
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'done_task',
          'تم الإنجاز ✅',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'snooze_10',
          'تأجيل 10 دقائق ⏱️',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      if (repeatType == 'weekdays' || repeatType == 'custom') {
        final days = (repeatDays != null && repeatDays.isNotEmpty)
            ? repeatDays
            : const <int>[1, 2, 3, 4, 5];

        for (final d in days) {
          final dayId = getNotificationId('$taskId:$d');
          final base = effectiveScheduledTime;
          var candidate = DateTime(
            base.year,
            base.month,
            base.day,
            base.hour,
            base.minute,
          );

          while (candidate.weekday != d || !candidate.isAfter(DateTime.now())) {
            candidate = candidate.add(const Duration(days: 1));
          }

          final tzScheduledTime = tz.TZDateTime.from(candidate, tz.local);
          await _notifications.zonedSchedule(
            dayId,
            taskTitle,
            taskDescription.isNotEmpty
                ? taskDescription
                : 'حان وقت هذه المهمة!',
            tzScheduledTime,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: 'task:$taskId',
          );
        }
        return;
      }

      final tzScheduledTime = tz.TZDateTime.from(
        effectiveScheduledTime,
        tz.local,
      );

      DateTimeComponents? matchComponents;
      if (repeatType == 'daily') {
        matchComponents = DateTimeComponents.time;
      } else if (repeatType == 'weekly') {
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
      }

      await _notifications.zonedSchedule(
        intId,
        taskTitle,
        taskDescription.isNotEmpty ? taskDescription : 'حان وقت هذه المهمة!',
        tzScheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: 'task:$taskId',
      );
    } catch (e) {
      debugPrint('خطأ في جدولة الإشعار: $e');
    }
  }

  /// إلغاء إشعار مجدول
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    await cancelNotification(getNotificationId(taskId));
    for (var d = 1; d <= 7; d++) {
      await cancelNotification(getNotificationId('$taskId:$d'));
    }
  }

  /// إلغاء جميع الإشعارات
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// التحقق من تفعيل الإشعارات
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? false;
      }
    }
    return true;
  }
}
