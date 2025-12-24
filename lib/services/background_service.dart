import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// خدمة إدارة خلفيات التطبيق
class BackgroundService {
  static const String _keyBackgroundType = 'background_type';
  static const String _keyBackgroundValue = 'background_value';
  static const String _keyOpacity = 'background_opacity';
  static const String _keyBlur = 'background_blur';

  // أنواع الخلفيات
  static const String typeNone = 'none';
  static const String typeAsset = 'asset';
  static const String typeCustom = 'custom';

  // الخلفيات المتاحة
  static const List<Map<String, String>> availableBackgrounds = [
    {
      'id': 'islamic_1',
      'name': 'زخرفة إسلامية 1',
      'path': 'assets/backgrounds/islamic_1.png',
    },
    {
      'id': 'islamic_2',
      'name': 'زخرفة إسلامية 2',
      'path': 'assets/backgrounds/islamic_2.png',
    },
    {
      'id': 'islamic_3',
      'name': 'زخرفة إسلامية 3',
      'path': 'assets/backgrounds/islamic_3.png',
    },
    {
      'id': 'gaming_1',
      'name': 'خلفية Gaming',
      'path': 'assets/backgrounds/gaming_1.png',
    },
  ];

  static String _backgroundType = typeNone;
  static String _backgroundValue = '';
  static double _opacity = 0.3; // شفافية الغطاء الداكن
  static double _blur = 0.0; // التمويه

  // Getters
  static String get backgroundType => _backgroundType;
  static String get backgroundValue => _backgroundValue;
  static double get opacity => _opacity;
  static double get blur => _blur;

  /// تحميل الإعدادات من التخزين
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _backgroundType = prefs.getString(_keyBackgroundType) ?? typeAsset;
    _backgroundValue =
        prefs.getString(_keyBackgroundValue) ??
        'assets/backgrounds/islamic_3.png';
    _opacity = prefs.getDouble(_keyOpacity) ?? 0.4;
    _blur = prefs.getDouble(_keyBlur) ?? 0.0;
  }

  /// تعيين خلفية من الأصول
  static Future<void> setAssetBackground(String assetPath) async {
    _backgroundType = typeAsset;
    _backgroundValue = assetPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackgroundType, _backgroundType);
    await prefs.setString(_keyBackgroundValue, _backgroundValue);
  }

  /// تعيين خلفية مخصصة من الهاتف
  static Future<bool> setCustomBackground(String sourcePath) async {
    try {
      // نسخ الصورة لمجلد التطبيق للحفظ الدائم
      final appDir = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${appDir.path}/backgrounds');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return false;

      final fileName = 'custom_bg_${DateTime.now().millisecondsSinceEpoch}.png';
      final destPath = '${bgDir.path}/$fileName';
      await sourceFile.copy(destPath);

      _backgroundType = typeCustom;
      _backgroundValue = destPath;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBackgroundType, _backgroundType);
      await prefs.setString(_keyBackgroundValue, _backgroundValue);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// تعيين الشفافية
  static Future<void> setOpacity(double value) async {
    _opacity = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOpacity, _opacity);
  }

  /// تعيين التمويه
  static Future<void> setBlur(double value) async {
    _blur = value.clamp(0.0, 20.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBlur, _blur);
  }

  /// إزالة الخلفية
  static Future<void> clearBackground() async {
    _backgroundType = typeNone;
    _backgroundValue = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackgroundType, _backgroundType);
    await prefs.setString(_keyBackgroundValue, _backgroundValue);
  }

  /// الحصول على widget الخلفية
  static Widget? getBackgroundWidget({
    double? customOpacity,
    bool isDarkMode = true,
  }) {
    if (_backgroundType == typeNone || _backgroundValue.isEmpty) {
      return null;
    }

    Widget? imageWidget;

    if (_backgroundType == typeAsset) {
      imageWidget = Image.asset(
        _backgroundValue,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    } else if (_backgroundType == typeCustom) {
      final file = File(_backgroundValue);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      }
    }

    if (imageWidget == null) return null;

    // تطبيق الشفافية والغطاء - يتكيف مع السمة
    final overlayOpacity = customOpacity ?? _opacity;
    final overlayColor = isDarkMode ? Colors.black : Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        Container(color: overlayColor.withValues(alpha: overlayOpacity)),
      ],
    );
  }

  /// هل توجد خلفية؟
  static bool hasBackground() {
    return _backgroundType != typeNone && _backgroundValue.isNotEmpty;
  }
}
