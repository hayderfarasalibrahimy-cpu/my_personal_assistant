import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'notification_service.dart';

/// خدمة المنبهات الصوتية
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final AudioPlayer _alarmPlayer = AudioPlayer();
  Timer? _alarmTimer;
  bool _isAlarmPlaying = false;

  // إعدادات المنبه
  static bool _alarmsEnabled = true;
  static double _alarmVolume = 1.0;
  static String _alarmSound =
      'assets/sounds/alarms/k-Rph1QwvMk.mp3'; // هادئ 3 🌸

  // الأصوات المتاحة للمنبه
  static const List<Map<String, String>> availableAlarmSounds = [
    // الأصوات الهادئة الطويلة (جديدة)
    {'name': 'هادئ 1 🌿', 'path': 'assets/sounds/alarms/2krSI3xEUiU.mp3'},
    {'name': 'هادئ 2 🌊', 'path': 'assets/sounds/alarms/LjWRjGpyaXg.mp3'},
    {'name': 'هادئ 3 🌸', 'path': 'assets/sounds/alarms/k-Rph1QwvMk.mp3'},
    {'name': 'هادئ 4 🍃', 'path': 'assets/sounds/alarms/nSVHb-eem1k.mp3'},
    {'name': 'هادئ 5 🌙', 'path': 'assets/sounds/alarms/pA1sX3Usxcw.mp3'},
    {'name': 'هادئ 6 ☁️', 'path': 'assets/sounds/alarms/qTAxER4SiEA.mp3'},
    // الأصوات القصيرة الأصلية
    {'name': 'تنبيه لطيف', 'path': 'assets/sounds/alarms/alarm_gentle.mp3'},
    {'name': 'نغمة رنين', 'path': 'assets/sounds/alarms/alarm_ringtone.mp3'},
    {'name': 'تنبيه ناعم', 'path': 'assets/sounds/alarms/alarm_soft_ding.mp3'},
    {
      'name': 'إشعار هادئ',
      'path': 'assets/sounds/alarms/alarm_notification.mp3',
    },
    {'name': 'تنبيه بسيط', 'path': 'assets/sounds/alarms/alarm_simple.mp3'},
    {'name': 'ضوء خفيف', 'path': 'assets/sounds/alarms/alarm_light.mp3'},
    {'name': 'دينغ صغير', 'path': 'assets/sounds/alarms/alarm_ding.mp3'},
    {'name': 'تنبيه كلاسيكي', 'path': 'assets/sounds/notification.mp3'},
  ];

  // Getters
  static bool get alarmsEnabled => _alarmsEnabled;
  static double get alarmVolume => _alarmVolume;
  static String get alarmSound => _alarmSound;
  bool get isAlarmPlaying => _isAlarmPlaying;

  /// تحميل الإعدادات
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _alarmsEnabled = prefs.getBool('alarms_enabled') ?? true;
    _alarmVolume = prefs.getDouble('alarm_volume') ?? 1.0;
    _alarmSound =
        prefs.getString('alarm_sound') ??
        'assets/sounds/alarms/k-Rph1QwvMk.mp3';
  }

  /// حفظ الإعدادات
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarms_enabled', _alarmsEnabled);
    await prefs.setDouble('alarm_volume', _alarmVolume);
    await prefs.setString('alarm_sound', _alarmSound);
  }

  /// تعيين إعدادات المنبه
  Future<void> setAlarmsEnabled(bool value) async {
    _alarmsEnabled = value;
    await saveSettings();
  }

  Future<void> setAlarmVolume(double value) async {
    _alarmVolume = value.clamp(0.0, 1.0);
    await saveSettings();
  }

  Future<void> setAlarmSound(String soundPath) async {
    _alarmSound = soundPath;
    await saveSettings();
  }

  /// تشغيل المنبه فوراً
  Future<void> playAlarm({
    required String title,
    String? body,
    TaskPriority priority = TaskPriority.medium,
    bool loop = true,
    bool showNotification = true,
  }) async {
    if (!_alarmsEnabled) return;

    debugPrint('بدء تشغيل المنبه: $title');

    // إذا كان المنبه يعمل بالفعل، لا تقم بتشغيله مرة أخرى
    if (_isAlarmPlaying) return;
    _isAlarmPlaying = true;

    // إرسالية إشعار مع المنبه
    if (showNotification) {
      try {
        await NotificationService().showNotification(
          title: title,
          body: body ?? 'حان وقت المهمة! 🚀',
          payload: 'alarm',
          soundPath: _alarmSound,
        );
        debugPrint('تم إرسال الإشعار بنجاح (الصوت سيعمل عبر الإشعار)');
      } catch (e) {
        debugPrint('خطأ في إرسال الإشعار: $e');
      }

      // ملاحظة: على أندرويد، الإشعار سيقوم بتشغيل الصوت.
      // سنستخدم AudioPlayer فقط إذا لم نرسل إشعاراً أو لغرض التكرار loop في المستقبل إذا لزم الأمر.
      // حالياً سنكتفي بصوت الإشعار لضمان عدم التكرار.
      return;
    }

    // تشغيل الصوت عبر AudioPlayer فقط إذا لم يكن هناك إشعار (مثلاً عند المعاينة داخل التطبيق)
    try {
      await stopAlarm();
      await _alarmPlayer.setVolume(_alarmVolume > 0 ? _alarmVolume : 1.0);
      await _alarmPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );

      final cleanPath = _alarmSound.replaceFirst('assets/', '');
      await _alarmPlayer.play(AssetSource(cleanPath));
      debugPrint('تم تشغيل الصوت عبر AudioPlayer');
    } catch (e) {
      debugPrint('خطأ في تشغيل الصوت: $e');
      _isAlarmPlaying = false;
    }
  }

  /// إيقاف المنبه
  Future<void> stopAlarm() async {
    _isAlarmPlaying = false;
    await _alarmPlayer.stop();
    _alarmTimer?.cancel();
    _alarmTimer = null;
  }

  /// تأجيل المنبه (Snooze)
  Future<void> snoozeAlarm({
    int snoozeMinutes = 5,
    String? title,
    String? body,
  }) async {
    await stopAlarm();

    // جدولة المنبه مرة أخرى
    _alarmTimer = Timer(Duration(minutes: snoozeMinutes), () {
      playAlarm(title: title ?? 'تذكير', body: body ?? 'المنبه المؤجل!');
    });
  }

  /// جدولة منبه في وقت محدد
  Future<void> scheduleAlarm({
    required DateTime scheduledTime,
    required String title,
    String? body,
    TaskPriority priority = TaskPriority.medium,
    bool loop = true,
    String? taskId,
    String repeatType = 'none',
    List<int>? repeatDays,
  }) async {
    if (!_alarmsEnabled) return;

    final now = DateTime.now();
    final duration = scheduledTime.difference(now);

    if (duration.isNegative) {
      debugPrint('وقت المنبه في الماضي!');
      return;
    }

    // توليد معرف فريد للمنبه
    final alarmId = scheduledTime.millisecondsSinceEpoch ~/ 1000;
    // استخدم taskId المعطى أو ولد واحداً من وقت المنبه
    final alarmIdStr = taskId ?? alarmId.toString();

    // جدولة إشعار عبر نظام Android (يعمل حتى لو كان التطبيق مغلقاً)
    try {
      await NotificationService().scheduleTaskReminder(
        taskId: alarmIdStr,
        taskTitle: title,
        taskDescription: body ?? 'حان وقت المهمة المجدولة! 🚀',
        scheduledTime: scheduledTime,
        soundPath: _alarmSound,
        repeatType: repeatType,
        repeatDays: repeatDays,
      );
      debugPrint('تم جدولة الإشعار الموحد بنجاح (ID: $alarmIdStr)');
    } catch (e) {
      debugPrint('خطأ في جدولة الإشعار: $e');
    }

    // ملاحظة: تم إزالة Timer الإضافي لمنع تكرار الصوت مع الإشعارات المجدولة
    debugPrint('تم جدولة المنبه بنجاح في: $scheduledTime');
  }

  /// جدولة منبه بعد فترة محددة
  Future<void> scheduleAlarmAfter({
    required Duration duration,
    required String title,
    String? body,
    String? taskId,
    TaskPriority priority = TaskPriority.medium,
    bool loop = true,
    String repeatType = 'none',
    List<int>? repeatDays,
  }) async {
    if (!_alarmsEnabled) return;

    final scheduledTime = DateTime.now().add(duration);
    // استخدم taskId المعطى أو ولد واحداً من وقت المنبه
    final alarmIdStr =
        taskId ?? (scheduledTime.millisecondsSinceEpoch ~/ 1000).toString();

    try {
      await NotificationService().scheduleTaskReminder(
        taskId: alarmIdStr,
        taskTitle: title,
        taskDescription:
            body ?? 'تذكير بموعد هذه المهمة كما خططت لها تماماً. ✨',
        scheduledTime: scheduledTime,
        soundPath: _alarmSound,
        repeatType: repeatType,
        repeatDays: repeatDays,
      );
      debugPrint('تم جدولة الإشعار الموحد بنجاح (ID: $alarmIdStr)');
    } catch (e) {
      debugPrint('خطأ في جدولة الإشعار: $e');
    }

    // ملاحظة: تم إزالة Timer الإضافي لمنع تكرار الصوت
    debugPrint('تم جدولة المنبه بنجاح بعد: $duration');
  }

  /// إلغاء منبه مجدول
  void cancelScheduledAlarm() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
  }

  /// تنظيف الموارد
  Future<void> dispose() async {
    await stopAlarm();
    await _alarmPlayer.dispose();
  }
}
