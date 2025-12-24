import 'package:shared_preferences/shared_preferences.dart';

/// خدمة لإدارة تفضيلات المستخدم وحفظ موقع الروبوت لكل شاشة
class UserPreferencesService {
  static const String _robotPositionPrefix = 'robot_position_';

  /// حفظ موقع الروبوت لشاشة معينة
  static Future<void> saveRobotPosition(
    String screenName,
    double x,
    double y,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_robotPositionPrefix${screenName}_x', x);
    await prefs.setDouble('$_robotPositionPrefix${screenName}_y', y);
  }

  /// استرجاع موقع الروبوت لشاشة معينة
  /// يرجع null إذا لم يكن هناك موقع محفوظ
  static Future<Map<String, double>?> getRobotPosition(
    String screenName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble('$_robotPositionPrefix${screenName}_x');
    final y = prefs.getDouble('$_robotPositionPrefix${screenName}_y');

    if (x != null && y != null) {
      return {'x': x, 'y': y};
    }
    return null;
  }

  /// الحصول على الموقع الافتراضي (على الحافة اليمنى السفلية)
  static Map<String, double> getDefaultPosition(
    double screenWidth,
    double screenHeight,
    double robotSize,
  ) {
    // الموقع الافتراضي: الحافة اليمنى السفلية مع هامش
    return {
      'x': screenWidth - robotSize - 20, // 20 بكسل من الحافة اليمنى
      'y': screenHeight - robotSize - 100, // 100 بكسل من الأسفل (للبار السفلي)
    };
  }

  /// مسح جميع المواقع المحفوظة
  static Future<void> clearAllPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_robotPositionPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
