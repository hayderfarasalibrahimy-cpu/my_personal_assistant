import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

/// خدمة تخصيص المساعد الشخصي
class AssistantCustomizationService {
  static const String _assistantNameKey = 'assistant_name';
  static const String _assistantPersonalityKey = 'assistant_personality';

  static String _assistantName = '';
  static String _assistantPersonality = 'default';

  // أسماء عراقية عشوائية
  static final List<String> _iraqiNames = [
    'زيدون',
    'ياسر',
    'عمار',
    'كرار',
    'علاء',
    'حسام',
    'بشار',
    'مصطفى',
    'أحمد',
    'محمد',
    'فراس',
    'عباس',
    'حسين',
    'علي',
    'جاسم',
  ];

  // الشخصيات المتاحة
  static const Map<String, String> personalities = {
    'default': 'الشخصية الافتراضية (ودود ومساعد)',
    'formal': 'رسمي ومحترف',
    'friendly': 'صديق مرح وودود',
    'wise': 'حكيم ومُلهم',
    'energetic': 'نشيط ومتحمس',
  };

  static String get assistantName => _assistantName;
  static String get assistantPersonality => _assistantPersonality;

  /// تحميل الإعدادات
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _assistantName = prefs.getString(_assistantNameKey) ?? '';
    _assistantPersonality =
        prefs.getString(_assistantPersonalityKey) ?? 'default';
  }

  /// تعيين اسم المساعد
  static Future<void> setAssistantName(String name) async {
    _assistantName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assistantNameKey, name);
  }

  /// تعيين شخصية المساعد
  static Future<void> setAssistantPersonality(String personality) async {
    _assistantPersonality = personality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assistantPersonalityKey, personality);
  }

  /// الحصول على اسم عشوائي عراقي
  static String getRandomIraqiName() {
    final random = Random();
    return _iraqiNames[random.nextInt(_iraqiNames.length)];
  }

  /// الحصول على اسم العرض للمساعد
  static String getDisplayName() {
    if (_assistantName.isNotEmpty) {
      return _assistantName;
    }
    return 'المساعد الذكي';
  }

  /// الحصول على وصف الشخصية للـ System Prompt
  static String getPersonalityDescription() {
    switch (_assistantPersonality) {
      case 'formal':
        return 'تحدث بأسلوب عملي، محترف، ومباشر. تجنب التكلف الزائد.';
      case 'friendly':
        return 'تحدث كصديق حقيقي، استخدم لغة بسيطة وعصرية مع إيموجي.';
      case 'wise':
        return 'تحدث بهدوء وحكمة وبساطة. أعطِ نصائح موزونة دون استخدام كلمات قديمة أو غريبة.';
      case 'energetic':
        return 'تحدث بحماس وطاقة إيجابية عالية.';
      default:
        return 'تحدث بأسلوب طبيعي، ودود، ومفيد.';
    }
  }

  /// إعادة تعيين الإعدادات
  static Future<void> resetToDefaults() async {
    await setAssistantName('');
    await setAssistantPersonality('default');
  }
}
