import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier لإعلام المستمعين بتغيير إعدادات الروبوت
class RobotSettingsNotifier extends ChangeNotifier {
  static final RobotSettingsNotifier _instance =
      RobotSettingsNotifier._internal();
  factory RobotSettingsNotifier() => _instance;
  RobotSettingsNotifier._internal();

  void notify() {
    notifyListeners();
  }
}

/// خدمة لإدارة إعدادات الروبوت المساعد
class RobotSettingsService {
  static const String _soundEnabledKey = 'robot_sound_enabled';
  static const String _vibrateEnabledKey = 'robot_vibrate_enabled';
  static const String _particlesEnabledKey = 'robot_particles_enabled';
  static const String _eyeBlinkEnabledKey = 'robot_eye_blink_enabled';
  static const String _armWaveEnabledKey = 'robot_arm_wave_enabled';
  static const String _draggableKey = 'robot_draggable';
  static const String _animationSpeedKey = 'robot_animation_speed';
  static const String _robotSizeKey = 'robot_size';
  static const String _autoGreetKey = 'robot_auto_greet';
  static const String _smartRemindersKey = 'robot_smart_reminders';
  static const String _showOnlyOnHomeKey = 'robot_show_only_on_home';
  static const String _isVisibleKey = 'robot_is_visible';
  static const String _platformStyleKey =
      'robot_platform_style'; // none, classic, modern, both
  static const String _bodyColorKey = 'robot_body_color';
  static const String _armsColorKey = 'robot_arms_color';
  static const String _legsColorKey = 'robot_legs_color';
  static const String _eyesColorKey = 'robot_eyes_color';
  static const String _eyesRimColorKey = 'robot_eyes_rim_color';
  static const String _eyesBgColorKey = 'robot_eyes_bg_color';
  static const String _faceColorKey = 'robot_face_color';
  static const String _mouthColorKey = 'robot_mouth_color';
  static const String _antennaColorKey = 'robot_antenna_color';
  static const String _earsColorKey = 'robot_ears_color';
  static const String _cheeksColorKey = 'robot_cheeks_color';
  static const String _glowColorKey = 'robot_glow_color';
  static const String _platformColorKey = 'robot_platform_color';

  // Default values
  static bool _soundEnabled = true;
  static bool _vibrateEnabled = true;
  static bool _particlesEnabled = false;
  static bool _eyeBlinkEnabled = true;
  static bool _armWaveEnabled = false;
  static bool _draggable = true;
  static double _animationSpeed = 1.0;
  static double _robotSize = 65.0;
  static bool _autoGreet = true;
  static bool _smartReminders = true;
  static bool _isVisible = true;
  static bool _showOnlyOnHome = false;
  static String _platformStyle = 'both';
  static String _bodyColor = '#2525AD';
  static String _armsColor = '#2525AD';
  static String _legsColor = '#2525AD';
  static String _eyesColor = '#2525AD';
  static String _eyesRimColor = '#BDBDBD'; // Grey 400
  static String _eyesBgColor = '#FFFFFF';
  static String _faceColor = '#252525';
  static String _mouthColor = '#BDBDBD'; // Grey 400
  static String _antennaColor = '#2525AD';
  static String _earsColor = '#000000';
  static String _cheeksColor = '#FF80AB'; // Pink Accent
  static String _glowColor = '#2525AD';
  static String _platformColor = '#2525AD';

  // Getters
  static bool get soundEnabled => _soundEnabled;
  static bool get vibrateEnabled => _vibrateEnabled;
  static bool get particlesEnabled => _particlesEnabled;
  static bool get eyeBlinkEnabled => _eyeBlinkEnabled;
  static bool get armWaveEnabled => _armWaveEnabled;
  static bool get draggable => _draggable;
  static double get animationSpeed => _animationSpeed;
  static double get robotSize => _robotSize;
  static bool get autoGreet => _autoGreet;
  static bool get smartReminders => _smartReminders;
  static bool get isVisible => _isVisible;
  static bool get showOnlyOnHome => _showOnlyOnHome;
  static String get platformStyle => _platformStyle;
  static String get bodyColor => _bodyColor;
  static String get armsColor => _armsColor;
  static String get legsColor => _legsColor;
  static String get eyesColor => _eyesColor;
  static String get eyesRimColor => _eyesRimColor;
  static String get eyesBgColor => _eyesBgColor;
  static String get faceColor => _faceColor;
  static String get mouthColor => _mouthColor;
  static String get antennaColor => _antennaColor;
  static String get earsColor => _earsColor;
  static String get cheeksColor => _cheeksColor;
  static String get glowColor => _glowColor;
  static String get platformColor => _platformColor;

  /// تحميل الإعدادات من SharedPreferences
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _vibrateEnabled = prefs.getBool(_vibrateEnabledKey) ?? true;
    _particlesEnabled = prefs.getBool(_particlesEnabledKey) ?? false;
    _eyeBlinkEnabled = prefs.getBool(_eyeBlinkEnabledKey) ?? true;
    _armWaveEnabled = prefs.getBool(_armWaveEnabledKey) ?? false;
    _draggable = prefs.getBool(_draggableKey) ?? true;
    _animationSpeed = prefs.getDouble(_animationSpeedKey) ?? 1.0;
    _robotSize = prefs.getDouble(_robotSizeKey) ?? 65.0;
    _autoGreet = prefs.getBool(_autoGreetKey) ?? true;
    _smartReminders = prefs.getBool(_smartRemindersKey) ?? true;
    _isVisible = prefs.getBool(_isVisibleKey) ?? true;
    _showOnlyOnHome = prefs.getBool(_showOnlyOnHomeKey) ?? false;
    _platformStyle = prefs.getString(_platformStyleKey) ?? 'both';
    _bodyColor = prefs.getString(_bodyColorKey) ?? '#2525AD';
    _armsColor = prefs.getString(_armsColorKey) ?? '#2525AD';
    _legsColor = prefs.getString(_legsColorKey) ?? '#2525AD';
    _eyesColor = prefs.getString(_eyesColorKey) ?? '#2525AD';
    _eyesRimColor = prefs.getString(_eyesRimColorKey) ?? '#BDBDBD';
    _eyesBgColor = prefs.getString(_eyesBgColorKey) ?? '#FFFFFF';
    _faceColor = prefs.getString(_faceColorKey) ?? '#252525';
    _mouthColor = prefs.getString(_mouthColorKey) ?? '#BDBDBD';
    _antennaColor = prefs.getString(_antennaColorKey) ?? '#2525AD';
    _earsColor = prefs.getString(_earsColorKey) ?? '#000000';
    _cheeksColor = prefs.getString(_cheeksColorKey) ?? '#FF80AB';
    _glowColor = prefs.getString(_glowColorKey) ?? '#2525AD';
    _platformColor = prefs.getString(_platformColorKey) ?? '#2525AD';
  }

  /// تفعيل/تعطيل الأصوات
  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }

  /// تفعيل/تعطيل ظهور الروبوت
  static Future<void> setIsVisible(bool visible) async {
    _isVisible = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isVisibleKey, visible);
    RobotSettingsNotifier().notify(); // إعلام المستمعين
  }

  /// تفعيل/تعطيل الاهتزاز
  static Future<void> setVibrateEnabled(bool enabled) async {
    _vibrateEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrateEnabledKey, enabled);
  }

  /// تفعيل/تعطيل الجسيمات المتطايرة
  static Future<void> setParticlesEnabled(bool enabled) async {
    _particlesEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_particlesEnabledKey, enabled);
  }

  /// تفعيل/تعطيل طرفة العين
  static Future<void> setEyeBlinkEnabled(bool enabled) async {
    _eyeBlinkEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eyeBlinkEnabledKey, enabled);
  }

  /// تفعيل/تعطيل تلويح الأذرع
  static Future<void> setArmWaveEnabled(bool enabled) async {
    _armWaveEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_armWaveEnabledKey, enabled);
  }

  /// تفعيل/تعطيل السحب والإفلات
  static Future<void> setDraggable(bool enabled) async {
    _draggable = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_draggableKey, enabled);
  }

  /// تعيين سرعة الحركة (0.5 - 2.0)
  static Future<void> setAnimationSpeed(double speed) async {
    _animationSpeed = speed.clamp(0.5, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_animationSpeedKey, _animationSpeed);
  }

  /// تعيين حجم الروبوت (80 - 200)
  static Future<void> setRobotSize(double size) async {
    _robotSize = size.clamp(40.0, 200.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_robotSizeKey, _robotSize);
    RobotSettingsNotifier().notify();
  }

  /// تفعيل/تعطيل التحية التلقائية
  static Future<void> setAutoGreet(bool enabled) async {
    _autoGreet = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoGreetKey, enabled);
  }

  /// تفعيل/تعطيل التذكيرات الذكية
  static Future<void> setSmartReminders(bool enabled) async {
    _smartReminders = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smartRemindersKey, enabled);
  }

  /// تفعيل/تعطيل "الظهور في الرئيسية فقط"
  static Future<void> setShowOnlyOnHome(bool value) async {
    _showOnlyOnHome = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showOnlyOnHomeKey, value);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setPlatformStyle(String style) async {
    _platformStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_platformStyleKey, style);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setBodyColor(String hex) async {
    _bodyColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bodyColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setArmsColor(String hex) async {
    _armsColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_armsColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setLegsColor(String hex) async {
    _legsColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legsColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setEyesColor(String hex) async {
    _eyesColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eyesColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setEyesRimColor(String hex) async {
    _eyesRimColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eyesRimColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setEyesBgColor(String hex) async {
    _eyesBgColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eyesBgColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setFaceColor(String hex) async {
    _faceColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_faceColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setMouthColor(String hex) async {
    _mouthColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mouthColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setAntennaColor(String hex) async {
    _antennaColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_antennaColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setEarsColor(String hex) async {
    _earsColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_earsColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setCheeksColor(String hex) async {
    _cheeksColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cheeksColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setGlowColor(String hex) async {
    _glowColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_glowColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  static Future<void> setPlatformColor(String hex) async {
    _platformColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_platformColorKey, hex);
    RobotSettingsNotifier().notify();
  }

  /// إعادة تعيين جميع الإعدادات للقيم الافتراضية
  static Future<void> resetToDefaults() async {
    await setSoundEnabled(true);
    await setVibrateEnabled(true);
    await setParticlesEnabled(false);
    await setEyeBlinkEnabled(true);
    await setArmWaveEnabled(false);
    await setDraggable(true);
    await setAnimationSpeed(1.0);
    await setRobotSize(80.0);
    await setAutoGreet(true);
    await setSmartReminders(true);
    await setIsVisible(true);
    await setShowOnlyOnHome(false);
    await setPlatformStyle('both');
    await setBodyColor('#2525AD');
    await setArmsColor('#2525AD');
    await setLegsColor('#2525AD');
    await setEyesColor('#2525AD');
    await setEyesRimColor('#BDBDBD');
    await setEyesBgColor('#FFFFFF');
    await setFaceColor('#252525');
    await setMouthColor('#BDBDBD');
    await setAntennaColor('#2525AD');
    await setEarsColor('#000000');
    await setCheeksColor('#FF80AB');
    await setGlowColor('#2525AD');
    await setPlatformColor('#2525AD');
  }
}
