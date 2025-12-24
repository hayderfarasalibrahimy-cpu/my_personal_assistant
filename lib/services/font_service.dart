import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة الخطوط العربية
class FontService {
  static const String _keySelectedFont = 'selected_font';

  // أسماء الخطوط المتاحة
  static const String fontDefault = 'default';
  static const String fontCairo = 'cairo';
  static const String fontAmiri = 'amiri';
  static const String fontTajawal = 'tajawal';
  static const String fontAlmarai = 'almarai';
  static const String fontNotoKufi = 'noto_kufi';
  static const String fontNotoNaskh = 'noto_naskh';
  static const String fontLateef = 'lateef';
  static const String fontScheherazade = 'scheherazade';
  static const String fontReem = 'reem';
  static const String fontMada = 'mada';
  static const String fontChanga = 'changa';
  static const String fontElMessiri = 'el_messiri';
  static const String fontMarkaziText = 'markazi';
  static const String fontLemonada = 'lemonada';
  static const String fontAref = 'aref';
  static const String fontIbmPlex = 'ibm_plex';
  static const String fontReadex = 'readex';

  static String _selectedFont = fontReadex; // الخط الافتراضي

  /// قائمة الخطوط المتاحة مع أسمائها العربية
  static final Map<String, String> availableFonts = {
    fontDefault: 'الخط الافتراضي',
    fontCairo: 'القاهرة',
    fontAmiri: 'الأميري',
    fontTajawal: 'تجوال',
    fontAlmarai: 'المراعي',
    fontNotoKufi: 'نوتو الكوفي',
    fontNotoNaskh: 'نوتو النسخ',
    fontLateef: 'لطيف',
    fontScheherazade: 'شهرزاد',
    fontReem: 'ريم الكوفي',
    fontMada: 'مدى',
    fontChanga: 'تشانجا',
    fontElMessiri: 'المصري',
    fontMarkaziText: 'مركزي',
    fontLemonada: 'ليمونادا',
    fontAref: 'عارف رقعة',
    fontIbmPlex: 'IBM Plex',
    fontReadex: 'Readex Pro',
  };

  /// الخط المحدد حالياً
  static String get selectedFont => _selectedFont;

  /// تحميل إعدادات الخط
  static Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedFont = prefs.getString(_keySelectedFont) ?? fontReadex;
    } catch (e) {
      _selectedFont = fontReadex;
    }
  }

  /// تغيير الخط
  static Future<void> setFont(String fontKey) async {
    if (!availableFonts.containsKey(fontKey)) return;

    _selectedFont = fontKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedFont, fontKey);
  }

  /// الحصول على TextTheme للخط المحدد مع توحيد الأحجام للمظهر المضغوط
  static TextTheme getTextTheme([TextTheme? base]) {
    final baseTheme = base ?? const TextTheme();

    // توحيد أحجام الخطوط لتناسب التصميم المضغوط والمساحات الصغيرة
    final unifiedTheme = baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(fontSize: 28),
      displayMedium: baseTheme.displayMedium?.copyWith(fontSize: 24),
      displaySmall: baseTheme.displaySmall?.copyWith(fontSize: 20),
      headlineLarge: baseTheme.headlineLarge?.copyWith(fontSize: 18),
      headlineMedium: baseTheme.headlineMedium?.copyWith(fontSize: 16),
      headlineSmall: baseTheme.headlineSmall?.copyWith(fontSize: 14),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(fontSize: 13),
      bodyMedium: baseTheme.bodyMedium?.copyWith(fontSize: 11),
      bodySmall: baseTheme.bodySmall?.copyWith(fontSize: 9),
      labelLarge: baseTheme.labelLarge?.copyWith(fontSize: 11),
      labelMedium: baseTheme.labelMedium?.copyWith(fontSize: 9),
      labelSmall: baseTheme.labelSmall?.copyWith(fontSize: 8),
    );

    switch (_selectedFont) {
      case fontCairo:
        return GoogleFonts.cairoTextTheme(unifiedTheme);
      case fontAmiri:
        return GoogleFonts.amiriTextTheme(unifiedTheme);
      case fontTajawal:
        return GoogleFonts.tajawalTextTheme(unifiedTheme);
      case fontAlmarai:
        return GoogleFonts.almaraiTextTheme(unifiedTheme);
      case fontNotoKufi:
        return GoogleFonts.notoKufiArabicTextTheme(unifiedTheme);
      case fontNotoNaskh:
        return GoogleFonts.notoNaskhArabicTextTheme(unifiedTheme);
      case fontLateef:
        return GoogleFonts.lateefTextTheme(unifiedTheme);
      case fontScheherazade:
        return GoogleFonts.scheherazadeNewTextTheme(unifiedTheme);
      case fontReem:
        return GoogleFonts.reemKufiTextTheme(unifiedTheme);
      case fontMada:
        return GoogleFonts.madaTextTheme(unifiedTheme);
      case fontChanga:
        return GoogleFonts.changaTextTheme(unifiedTheme);
      case fontElMessiri:
        return GoogleFonts.elMessiriTextTheme(unifiedTheme);
      case fontMarkaziText:
        return GoogleFonts.markaziTextTextTheme(unifiedTheme);
      case fontLemonada:
        return GoogleFonts.lemonadaTextTheme(unifiedTheme);
      case fontAref:
        return GoogleFonts.arefRuqaaTextTheme(unifiedTheme);
      case fontIbmPlex:
        return GoogleFonts.ibmPlexSansArabicTextTheme(unifiedTheme);
      case fontReadex:
        return GoogleFonts.readexProTextTheme(unifiedTheme);
      case fontDefault:
      default:
        return unifiedTheme;
    }
  }

  /// الحصول على TextStyle للخط المحدد
  static TextStyle getTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return getFontTextStyle(
      _selectedFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// الحصول على TextStyle لخط معين (لأغراض المعاينة)
  static TextStyle getFontTextStyle(
    String fontKey, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    switch (fontKey) {
      case fontCairo:
        return GoogleFonts.cairo(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontAmiri:
        return GoogleFonts.amiri(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontTajawal:
        return GoogleFonts.tajawal(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontAlmarai:
        return GoogleFonts.almarai(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontNotoKufi:
        return GoogleFonts.notoKufiArabic(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontNotoNaskh:
        return GoogleFonts.notoNaskhArabic(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontLateef:
        return GoogleFonts.lateef(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontScheherazade:
        return GoogleFonts.scheherazadeNew(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontReem:
        return GoogleFonts.reemKufi(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontMada:
        return GoogleFonts.mada(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontChanga:
        return GoogleFonts.changa(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontElMessiri:
        return GoogleFonts.elMessiri(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontMarkaziText:
        return GoogleFonts.markaziText(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontLemonada:
        return GoogleFonts.lemonada(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontAref:
        return GoogleFonts.arefRuqaa(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontIbmPlex:
        return GoogleFonts.ibmPlexSansArabic(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontReadex:
        return GoogleFonts.readexPro(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case fontDefault:
      default:
        return TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
    }
  }

  /// معاينة الخط (نص عينة)
  static String get sampleText => 'مذكرة الحياة';
}
