import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة بيانات المستخدم
class UserService {
  static const String _keyUserName = 'user_name';
  static const String _keyUserGender = 'user_gender'; // 'male' or 'female'
  static const String _keyUserAvatar = 'user_avatar';
  static const String _keyIsFirstLaunch = 'is_first_launch';

  /// التحقق من أول تشغيل للتطبيق
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsFirstLaunch) ?? true;
  }

  /// تعيين أن التطبيق تم تشغيله
  static Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsFirstLaunch, false);
  }

  /// حفظ بيانات المستخدم
  static Future<void> saveUserData({
    required String name,
    required String gender,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserGender, gender);
    await setFirstLaunchComplete();
  }

  /// الحصول على اسم المستخدم
  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? '';
  }

  /// الحصول على جنس المستخدم
  static Future<String> getUserGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserGender) ?? 'male';
  }

  /// الحصول على الترحيب المخصص
  static Future<String> getPersonalizedGreeting() async {
    final name = await getUserName();
    final gender = await getUserGender();

    if (name.isEmpty) {
      return 'أهلاً بك';
    }

    final title = gender == 'female' ? 'سيدة' : 'سيد';
    return 'أهلاً بك يا $title $name';
  }

  /// الحصول على صورة المستخدم (رابط ملف أو اسم افتراضي)
  static Future<String> getUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserAvatar) ?? 'avatar_1';
  }

  /// حفظ صورة المستخدم
  static Future<void> saveUserAvatar(String avatarPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserAvatar, avatarPath);
  }

  /// إعادة تعيين بيانات المستخدم (للاختبار)
  static Future<void> resetUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserGender);
    await prefs.remove(_keyUserAvatar);
    await prefs.setBool(_keyIsFirstLaunch, true);
  }
}
