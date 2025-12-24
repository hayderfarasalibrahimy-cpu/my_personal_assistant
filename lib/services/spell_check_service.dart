import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// خدمة التدقيق الإملائي للعربية والإنجليزية
class SpellCheckServiceCustom {
  static SpellCheckServiceCustom? _instance;
  Set<String> _dictionary = {};
  bool _isInitialized = false;

  SpellCheckServiceCustom._();

  static SpellCheckServiceCustom get instance {
    _instance ??= SpellCheckServiceCustom._();
    return _instance!;
  }

  /// تهيئة خدمة التدقيق الإملائي
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // تحميل القاموس العربي من الأصول
      final String dictionaryContent = await rootBundle.loadString(
        'assets/dictionaries/arabic_dictionary.txt',
      );

      // تقسيم القاموس إلى كلمات وإضافتها للمجموعة
      _dictionary = dictionaryContent
          .split('\n')
          .map((word) => word.trim())
          .where((word) => word.isNotEmpty)
          .toSet();

      _isInitialized = true;
    } catch (e) {
      debugPrint('خطأ في تهيئة خدمة التدقيق الإملائي: $e');
      _isInitialized = false;
    }
  }

  /// التحقق من صحة كلمة
  bool isWordCorrect(String word) {
    if (!_isInitialized) return true;

    // تنظيف الكلمة من علامات الترقيم
    final cleanWord = word.trim().replaceAll(
      RegExp(r'[^\u0600-\u06FFa-zA-Z]'),
      '',
    );
    if (cleanWord.isEmpty) return true;

    // التحقق من وجود الكلمة في القاموس
    return _dictionary.contains(cleanWord);
  }

  /// التحقق من النص وإرجاع الكلمات الخاطئة مع مواضعها
  List<SpellError> checkText(String text) {
    if (!_isInitialized) return [];

    final List<SpellError> errors = [];
    final words = text.split(RegExp(r'\s+'));
    int currentPosition = 0;

    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z]'), '');

      if (cleanWord.isNotEmpty && !isWordCorrect(cleanWord)) {
        final startIndex = text.indexOf(word, currentPosition);
        if (startIndex >= 0) {
          errors.add(
            SpellError(
              word: word,
              startIndex: startIndex,
              endIndex: startIndex + word.length,
            ),
          );
        }
      }

      final wordIndex = text.indexOf(word, currentPosition);
      if (wordIndex >= 0) {
        currentPosition = wordIndex + word.length;
      }
    }

    return errors;
  }

  /// الحصول على اقتراحات لكلمة خاطئة (بسيطة - يمكن تحسينها لاحقاً)
  List<String> getSuggestions(String word) {
    if (!_isInitialized) return [];

    final cleanWord = word.trim().replaceAll(
      RegExp(r'[^\u0600-\u06FFa-zA-Z]'),
      '',
    );
    if (cleanWord.isEmpty) return [];

    // البحث عن كلمات مشابهة في القاموس
    final suggestions = <String>[];
    for (final dictWord in _dictionary) {
      if (dictWord.startsWith(cleanWord.substring(0, 1))) {
        suggestions.add(dictWord);
        if (suggestions.length >= 5) break;
      }
    }

    return suggestions;
  }

  /// إضافة كلمة للقاموس المخصص
  void addWordToDictionary(String word) {
    if (!_isInitialized) return;

    final cleanWord = word.trim().replaceAll(
      RegExp(r'[^\u0600-\u06FFa-zA-Z]'),
      '',
    );
    if (cleanWord.isEmpty) return;

    _dictionary.add(cleanWord);
  }
}

/// فئة لتمثيل خطأ إملائي
class SpellError {
  final String word;
  final int startIndex;
  final int endIndex;

  SpellError({
    required this.word,
    required this.startIndex,
    required this.endIndex,
  });
}
