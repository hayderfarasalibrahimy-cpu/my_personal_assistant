import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة الأصوات التفاعلية مع دعم التخصيص
class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  // الإعدادات
  static bool _soundEnabled = true;
  static bool _hapticEnabled = true;

  // Debouncing لمنع تشغيل الصوت المتكرر بسرعة
  static DateTime? _lastSoundTime;
  static const Duration _debounceDelay = Duration(milliseconds: 100);

  // الأصوات المتاحة
  static const List<String> availableClickSounds = [
    'click.mp3',
    'click2.mp3',
    'click3.mp3',
    'click4.mp3',
    'click5.mp3',
    'click6.mp3',
    'click7.mp3',
    'click8.mp3',
    'click9.mp3',
  ];
  static const List<String> availableSuccessSounds = [
    'success.mp3',
    'success2.mp3',
    'success3.mp3',
    'success4.mp3',
    'success5.mp3',
    'success6.mp3',
    'success7.mp3',
    'success8.mp3',
  ];
  static const List<String> availableDeleteSounds = [
    'delete.mp3',
    'delete2.mp3',
    'delete3.mp3',
    'delete4.mp3',
    'delete5.mp3',
    'delete6.mp3',
    'delete7.mp3',
    'delete8.mp3',
  ];
  static const List<String> availableNotificationSounds = [
    'notification.mp3',
    'success.mp3',
  ];

  // الأصوات المحددة حالياً
  static String _selectedClickSound = 'click7.mp3';
  static String _selectedSuccessSound = 'success.mp3';
  static String _selectedDeleteSound = 'delete4.mp3';
  static String _selectedNotificationSound = 'notification.mp3';

  // مفاتيح التخزين
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyHapticEnabled = 'haptic_enabled';
  static const String _keyClickSound = 'click_sound';
  static const String _keySuccessSound = 'success_sound';
  static const String _keyDeleteSound = 'delete_sound';
  static const String _keyNotificationSound = 'notification_sound';

  /// تحميل الإعدادات من التخزين
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
    _hapticEnabled = prefs.getBool(_keyHapticEnabled) ?? true;
    _selectedClickSound = prefs.getString(_keyClickSound) ?? 'click7.mp3';
    _selectedSuccessSound = prefs.getString(_keySuccessSound) ?? 'success.mp3';
    _selectedDeleteSound = prefs.getString(_keyDeleteSound) ?? 'delete4.mp3';
    _selectedNotificationSound =
        prefs.getString(_keyNotificationSound) ?? 'notification.mp3';
  }

  // Getters
  static bool get isSoundEnabled => _soundEnabled;
  static bool get isHapticEnabled => _hapticEnabled;
  static String get selectedClickSound => _selectedClickSound;
  static String get selectedSuccessSound => _selectedSuccessSound;
  static String get selectedDeleteSound => _selectedDeleteSound;
  static String get selectedNotificationSound => _selectedNotificationSound;

  /// تفعيل/إلغاء الأصوات
  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, enabled);
  }

  /// تفعيل/إلغاء الاهتزاز
  static Future<void> setHapticEnabled(bool enabled) async {
    _hapticEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHapticEnabled, enabled);
  }

  /// تعيين صوت النقر
  static Future<void> setClickSound(String sound) async {
    _selectedClickSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClickSound, sound);
  }

  /// تعيين صوت النجاح
  static Future<void> setSuccessSound(String sound) async {
    _selectedSuccessSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySuccessSound, sound);
  }

  /// تعيين صوت الحذف
  static Future<void> setDeleteSound(String sound) async {
    _selectedDeleteSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeleteSound, sound);
  }

  /// تعيين صوت الإشعار
  static Future<void> setNotificationSound(String sound) async {
    _selectedNotificationSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotificationSound, sound);
  }

  /// صوت النقر على الأزرار
  static Future<void> playClick() async {
    _doHaptic('light');
    if (!_soundEnabled) return;

    // منع التشغيل المتكرر بسرعة
    final now = DateTime.now();
    if (_lastSoundTime != null &&
        now.difference(_lastSoundTime!) < _debounceDelay) {
      return;
    }
    _lastSoundTime = now;

    try {
      // استخدام الوضع الافتراضي لتجنب مشاكل التوافق وانهيار النظام (Crash)
      await _player.stop();
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.play(
        AssetSource('sounds/$_selectedClickSound'),
        volume: 0.5,
      );
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  /// صوت النجاح - عند إكمال مهمة أو حفظ
  static Future<void> playSuccess() async {
    _doHaptic('medium');
    if (!_soundEnabled) return;

    try {
      await _player.stop();
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.play(
        AssetSource('sounds/$_selectedSuccessSound'),
        volume: 0.6,
      );
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  /// صوت الحذف
  static Future<void> playDelete() async {
    _doHaptic('heavy');
    if (!_soundEnabled) return;

    try {
      await _player.stop();
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.play(
        AssetSource('sounds/$_selectedDeleteSound'),
        volume: 0.5,
      );
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  /// صوت التنبيه/الخطأ
  static Future<void> playError() async {
    _doHaptic('vibrate');
    if (!_soundEnabled) return;

    try {
      await _player.stop();
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.play(AssetSource('sounds/error.mp3'), volume: 0.5);
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  /// صوت الإشعار
  static Future<void> playNotification() async {
    _doHaptic('medium');
    if (!_soundEnabled) return;

    try {
      await _player.stop();
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.play(
        AssetSource('sounds/$_selectedNotificationSound'),
        volume: 0.7,
      );
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  static String? _currentPlayingSound;
  static String? get currentPlayingSound => _currentPlayingSound;

  /// تشغيل صوت للمعاينة
  static Future<void> previewSound(String soundFile) async {
    try {
      await _player.stop();
      _currentPlayingSound = soundFile;
      await _player.play(AssetSource('sounds/$soundFile'), volume: 0.6);

      // Reset when done (optional, but good for UI)
      _player.onPlayerComplete.first.then((_) {
        _currentPlayingSound = null;
      });
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  /// إيقاف جميع الأصوات المشغلة حالياً
  static Future<void> stopAllSounds() async {
    try {
      await _player.stop();
      _currentPlayingSound = null;
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  /// هل هناك صوت قيد التشغيل حالياً؟
  static bool get isSoundPlaying => _player.state == PlayerState.playing;

  /// للاستماع لحالة المشغل (لتحديث الواجهة)
  static Stream<PlayerState> get onPlayerStateChanged =>
      _player.onPlayerStateChanged;

  /// تنفيذ الاهتزاز
  static void _doHaptic(String type) {
    if (!_hapticEnabled) return;

    switch (type) {
      case 'light':
        HapticFeedback.lightImpact();
        break;
      case 'medium':
        HapticFeedback.mediumImpact();
        break;
      case 'heavy':
        HapticFeedback.heavyImpact();
        break;
      case 'vibrate':
        HapticFeedback.vibrate();
        break;
      case 'selection':
        HapticFeedback.selectionClick();
        break;
    }
  }

  /// تحرير الموارد
  static void dispose() {
    _player.dispose();
  }
}
