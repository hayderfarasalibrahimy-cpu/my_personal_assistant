/// خدمة الترقيم التلقائي للقوائم
class AutoNumberingService {
  /// أنماط الترقيم المدعومة
  static const String numeric = 'numeric'; // 1. 2. 3.
  static const String bullet = 'bullet'; // • • •
  static const String dash = 'dash'; // - - -
  static const String alphabetic = 'alphabetic'; // أ. ب. ج.

  /// اكتشاف نمط الترقيم من النص
  static String? detectNumberingPattern(String line) {
    final trimmedLine = line.trim();

    // اكتشاف الترقيم الرقمي: 1. أو 1- أو 1)
    if (RegExp(r'^\d+[\.\-\)]').hasMatch(trimmedLine)) {
      return numeric;
    }

    // اكتشاف النقاط: • أو * أو ○
    if (RegExp(r'^[•\*○◦▪▫]').hasMatch(trimmedLine)) {
      return bullet;
    }

    // اكتشاف الشرطة: -
    if (RegExp(r'^[\-–—]').hasMatch(trimmedLine)) {
      return dash;
    }

    // اكتشاف الترقيم الأبجدي العربي: أ. ب. ج.
    if (RegExp(r'^[أ-ي][\.\-\)]').hasMatch(trimmedLine)) {
      return alphabetic;
    }

    return null;
  }

  /// استخراج رقم العنصر من السطر
  static int? extractNumber(String line) {
    final trimmedLine = line.trim();
    final match = RegExp(r'^\d+').firstMatch(trimmedLine);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }

  /// استخراج الحرف الأبجدي من السطر
  static String? extractAlphabetic(String line) {
    final trimmedLine = line.trim();
    final match = RegExp(r'^[أ-ي]').firstMatch(trimmedLine);
    return match?.group(0);
  }

  /// الحصول على الرقم التالي
  static String getNextNumber(String pattern, String currentLine) {
    switch (pattern) {
      case numeric:
        final currentNumber = extractNumber(currentLine) ?? 0;
        return '${currentNumber + 1}.';

      case bullet:
        return '•';

      case dash:
        return '-';

      case alphabetic:
        final currentLetter = extractAlphabetic(currentLine);
        if (currentLetter != null) {
          final nextLetter = _getNextArabicLetter(currentLetter);
          return '$nextLetter.';
        }
        return 'أ.';

      default:
        return '';
    }
  }

  /// الحصول على الحرف العربي التالي
  static String _getNextArabicLetter(String letter) {
    const arabicLetters = [
      'أ',
      'ب',
      'ج',
      'د',
      'ه',
      'و',
      'ز',
      'ح',
      'ط',
      'ي',
      'ك',
      'ل',
      'م',
      'ن',
      'س',
      'ع',
      'ف',
      'ص',
      'ق',
      'ر',
      'ش',
      'ت',
      'ث',
      'خ',
      'ذ',
      'ض',
      'ظ',
      'غ',
    ];

    final index = arabicLetters.indexOf(letter);
    if (index >= 0 && index < arabicLetters.length - 1) {
      return arabicLetters[index + 1];
    }
    return 'أ'; // العودة للبداية
  }

  /// تحويل نص إلى نمط ترقيم معين
  static String convertToPattern(String text, String targetPattern) {
    final lines = text.split('\n');
    final convertedLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final currentPattern = detectNumberingPattern(line);

      if (currentPattern != null) {
        // إزالة الترقيم الحالي
        final content = line.replaceFirst(
          RegExp(r'^[\d•\*○◦▪▫\-–—أ-ي]+[\.\-\)]\s*'),
          '',
        );

        // إضافة الترقيم الجديد
        String newNumbering;
        switch (targetPattern) {
          case numeric:
            newNumbering = '${i + 1}.';
            break;
          case bullet:
            newNumbering = '•';
            break;
          case dash:
            newNumbering = '-';
            break;
          case alphabetic:
            final arabicLetters = [
              'أ',
              'ب',
              'ج',
              'د',
              'ه',
              'و',
              'ز',
              'ح',
              'ط',
              'ي',
            ];
            newNumbering = '${arabicLetters[i % arabicLetters.length]}.';
            break;
          default:
            newNumbering = '';
        }

        convertedLines.add('$newNumbering $content');
      } else {
        convertedLines.add(line);
      }
    }

    return convertedLines.join('\n');
  }

  /// إضافة ترقيم تلقائي للنص
  static String autoNumber(String text, String pattern) {
    final lines = text.split('\n');
    final numberedLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        numberedLines.add('');
        continue;
      }

      String numbering;
      switch (pattern) {
        case numeric:
          numbering = '${i + 1}.';
          break;
        case bullet:
          numbering = '•';
          break;
        case dash:
          numbering = '-';
          break;
        case alphabetic:
          final arabicLetters = [
            'أ',
            'ب',
            'ج',
            'د',
            'ه',
            'و',
            'ز',
            'ح',
            'ط',
            'ي',
          ];
          numbering = '${arabicLetters[i % arabicLetters.length]}.';
          break;
        default:
          numbering = '';
      }

      numberedLines.add('$numbering $line');
    }

    return numberedLines.join('\n');
  }

  /// إزالة الترقيم من النص
  static String removeNumbering(String text) {
    final lines = text.split('\n');
    final cleanLines = <String>[];

    for (final line in lines) {
      final cleanLine = line.replaceFirst(
        RegExp(r'^[\d•\*○◦▪▫\-–—أ-ي]+[\.\-\)]\s*'),
        '',
      );
      cleanLines.add(cleanLine);
    }

    return cleanLines.join('\n');
  }
}
