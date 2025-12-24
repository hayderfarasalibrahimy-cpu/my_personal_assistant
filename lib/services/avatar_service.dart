import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// خدمة إدارة أفاتار المساعد الذكي مع ملفات Lottie المحلية
class AvatarService {
  static const String _avatarTypeKey = 'assistant_avatar_type';
  static const String _avatarIndexKey = 'assistant_avatar_index';
  static const String _customAvatarPathKey = 'custom_avatar_path';

  static String _avatarType = 'default'; // 'default' أو 'custom'
  static int _avatarIndex = 0;
  static String _customAvatarPath = '';

  // الأفاتار الافتراضية من ملفات Lottie المحلية (7 أفاتار متحركة احترافية)
  static final List<LottieAvatarData> defaultAvatars = [
    LottieAvatarData(
      name: 'روبوت المحادثة',
      lottieAsset: 'assets/chat pot.lottie',
      fallbackIcon: Icons.chat_bubble_outline,
      color: Color(0xFF2196F3),
    ),
    LottieAvatarData(
      name: 'الروبوت المفكر',
      lottieAsset: 'assets/ROBOT-THINK.lottie',
      fallbackIcon: Icons.psychology,
      color: Color(0xFF9C27B0),
    ),
    LottieAvatarData(
      name: 'روبوت ثلاثي الأبعاد',
      lottieAsset: 'assets/Robot-Bot 3D.lottie',
      fallbackIcon: Icons.smart_toy,
      color: Color(0xFF4CAF50),
    ),
    LottieAvatarData(
      name: 'المحادثة الحية',
      lottieAsset: 'assets/Live chatbot.lottie',
      fallbackIcon: Icons.support_agent,
      color: Color(0xFFFF5722),
    ),
    LottieAvatarData(
      name: 'روبوت فني',
      lottieAsset: 'assets/Ai Robot Vector Art.lottie',
      fallbackIcon: Icons.android,
      color: Color(0xFF00BCD4),
    ),
    LottieAvatarData(
      name: 'شبكة الذكاء',
      lottieAsset: 'assets/AI network.lottie',
      fallbackIcon: Icons.hub,
      color: Color(0xFF3F51B5),
    ),
    LottieAvatarData(
      name: 'الماسح الذكي',
      lottieAsset: 'assets/Scanning.lottie',
      fallbackIcon: Icons.radar,
      color: Color(0xFFE91E63),
    ),
  ];

  // Getters
  static String get avatarType => _avatarType;
  static int get avatarIndex => _avatarIndex;
  static String get customAvatarPath => _customAvatarPath;
  static LottieAvatarData get currentDefaultAvatar =>
      defaultAvatars[_avatarIndex];

  /// تحميل الإعدادات
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _avatarType = prefs.getString(_avatarTypeKey) ?? 'default';
    _avatarIndex = prefs.getInt(_avatarIndexKey) ?? 0;
    _customAvatarPath = prefs.getString(_customAvatarPathKey) ?? '';

    // التأكد من صحة الفهرس
    if (_avatarIndex < 0 || _avatarIndex >= defaultAvatars.length) {
      _avatarIndex = 0;
    }
  }

  /// تعيين أفاتار افتراضي
  static Future<void> setDefaultAvatar(int index) async {
    if (index < 0 || index >= defaultAvatars.length) return;

    _avatarType = 'default';
    _avatarIndex = index;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarTypeKey, 'default');
    await prefs.setInt(_avatarIndexKey, index);
  }

  /// تعيين أفاتار مخصص من صورة
  static Future<void> setCustomAvatar(File imageFile) async {
    // الحصول على مجلد التطبيق
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${appDir.path}/avatars');

    // إنشاء المجلد إذا لم يكن موجوداً
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    // حفظ الصورة
    final fileName =
        'custom_avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final savedPath = '${avatarDir.path}/$fileName';
    await imageFile.copy(savedPath);

    // حذف الصورة القديمة إذا وجدت
    if (_customAvatarPath.isNotEmpty) {
      final oldFile = File(_customAvatarPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }

    _avatarType = 'custom';
    _customAvatarPath = savedPath;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarTypeKey, 'custom');
    await prefs.setString(_customAvatarPathKey, savedPath);
  }

  /// التحقق من وجود صورة مخصصة صالحة
  static Future<bool> hasValidCustomAvatar() async {
    if (_customAvatarPath.isEmpty) return false;
    final file = File(_customAvatarPath);
    return await file.exists();
  }

  /// إعادة تعيين للافتراضي
  static Future<void> resetToDefault() async {
    await setDefaultAvatar(0);
  }
}

/// بيانات الأفاتار مع Lottie (ملفات محلية)
class LottieAvatarData {
  final String name;
  final String lottieAsset; // مسار الملف المحلي
  final IconData fallbackIcon;
  final Color color;

  const LottieAvatarData({
    required this.name,
    required this.lottieAsset,
    required this.fallbackIcon,
    required this.color,
  });
}
