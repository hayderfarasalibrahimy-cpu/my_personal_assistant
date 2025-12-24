import 'package:flutter/material.dart';

class TextUtils {
  /// يتحقق مما إذا كان النص يبدأ بلغة عربية أو لغة RTL
  static bool isRTL(String text) {
    if (text.isEmpty) return true; // الافتراضي للتطبيق هو RTL

    // البحث عن أول حرف أبجدي
    for (int i = 0; i < text.length; i++) {
      final charCode = text.codeUnitAt(i);

      // نطاق الأحرف العربية في Unicode
      if (charCode >= 0x0600 && charCode <= 0x06FF) {
        return true;
      }

      // نطاق الأحرف اللاتينية (الإنجليزية)
      if ((charCode >= 0x0041 && charCode <= 0x005A) ||
          (charCode >= 0x0061 && charCode <= 0x007A)) {
        return false;
      }
    }

    return true; // الافتراضي إذا لم يتم العثور على أحرف واضحة
  }

  /// إرجاع اتجاه النص بناءً على المحتوى
  static TextDirection getTextDirection(String text) {
    return isRTL(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// إرجاع محاذاة النص بناءً على المحتوى
  static TextAlign getTextAlign(String text) {
    return isRTL(text) ? TextAlign.right : TextAlign.left;
  }
}
