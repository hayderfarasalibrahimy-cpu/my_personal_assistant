import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// خدمة تحويل النص إلى كلام
class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;
  static bool _isSpeaking = false;
  static bool _isEnabled = true;

  /// تهيئة الخدمة مع آلية إعادة المحاولة
  static Future<void> initialize({int retries = 3}) async {
    if (_isInitialized) return;

    if (!kIsWeb && Platform.isWindows) return;

    for (int i = 0; i < retries; i++) {
      try {
        debugPrint('TTS: Initialization attempt ${i + 1} starting...');

        // محاولة ضبط اللغة مع Timeout أطول
        await _flutterTts.setLanguage('ar').timeout(Duration(seconds: 5));
        debugPrint('TTS: Language set to ar');

        await _flutterTts.setSpeechRate(0.5).timeout(Duration(seconds: 2));
        await _flutterTts.setVolume(1.0).timeout(Duration(seconds: 2));
        await _flutterTts.setPitch(1.0).timeout(Duration(seconds: 2));
        await _flutterTts
            .awaitSpeakCompletion(true)
            .timeout(Duration(seconds: 2));

        _flutterTts.setStartHandler(() {
          _isSpeaking = true;
          debugPrint('TTS: Playing...');
        });
        _flutterTts.setCompletionHandler(() {
          debugPrint('TTS: Complete');
          _isSpeaking = false;
        });
        _flutterTts.setCancelHandler(() => _isSpeaking = false);
        _flutterTts.setErrorHandler((msg) {
          debugPrint('TTS Error: $msg');
          _isSpeaking = false;
        });

        // ضبط المحرك (اختياري)
        if (Platform.isAndroid) {
          try {
            await _flutterTts
                .setEngine('com.google.android.tts')
                .timeout(Duration(seconds: 3));
            debugPrint('TTS: Google Engine set');
          } catch (_) {
            debugPrint('TTS: Using default engine');
          }
          await _flutterTts.setQueueMode(1);
        }

        _isInitialized = true;
        debugPrint('TTS: Initialized Successfully');
        return;
      } catch (e) {
        debugPrint('TTS Initialization failed: $e');
        if (i < retries - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }
  }

  /// نطق النص
  static Future<void> speak(String text) async {
    if ((!kIsWeb && Platform.isWindows) || !_isInitialized || !_isEnabled) {
      return;
    }

    // تنظيف النص قبل النطق
    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return;

    try {
      if (_isSpeaking) {
        await stop();
      }
      final chunks = _chunkText(cleanText);
      for (final chunk in chunks) {
        _isSpeaking = true;
        await _flutterTts.speak(chunk);
      }
    } catch (e) {
      debugPrint('Error speaking: $e');
      _isSpeaking = false;
    }
  }

  /// إيقاف النطق
  static Future<void> stop() async {
    if ((!kIsWeb && Platform.isWindows) || !_isInitialized) return;
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  static bool get isEnabled => _isEnabled;

  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!_isEnabled) {
      await stop();
    }
  }

  static Future<void> toggleEnabled() async {
    await setEnabled(!_isEnabled);
  }

  /// تنظيف النص من الرموز غير المهمة للنطق
  static String _cleanText(String text) {
    // إزالة الرموز التعبيرية
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F700}-\u{1F77F}]|[\u{1F780}-\u{1F7FF}]|[\u{1F800}-\u{1F8FF}]|[\u{1F900}-\u{1F9FF}]|[\u{1FA00}-\u{1FA6F}]|[\u{1FA70}-\u{1FAFF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
      unicode: true,
    );

    // إزالة وسوم XML/HTML (مثل <voice-TTS>)
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), ' ');

    // إزالة رموز MarkDown والرموز الخاصة
    cleaned = cleaned
        .replaceAll(emojiRegex, '')
        .replaceAll(RegExp(r'\*\*|__'), '') // عريض
        .replaceAll(RegExp(r'\*|_'), '') // مائل
        .replaceAll(RegExp(r'```.*?```', dotAll: true), 'كود برمجي') // كود
        .replaceAll(RegExp(r'`.*?`'), '') // كود سطري
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // روابط
        .replaceAll(RegExp(r'[\{\}\[\]\(\)\<\>]'), ' ') // حاصرات
        .replaceAll(RegExp(r'#+'), ' ') // عناوين
        .replaceAll(RegExp(r'\s+'), ' ') // مسافات زائدة
        .trim();

    return cleaned;
  }

  /// تقسيم النص لقطع قصيرة لتجنب توقف المحرك في النصوص الطويلة
  static List<String> _chunkText(String text, {int maxLength = 300}) {
    if (text.length <= maxLength) return [text];

    final sentences = text
        .split(RegExp(r'(?<=[.!؟])\s+'))
        .where((s) => s.trim().isNotEmpty);
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if ((buffer.length + sentence.length + 1) <= maxLength) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(sentence);
      } else {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
        if (sentence.length <= maxLength) {
          buffer.write(sentence);
        } else {
          // تقسيم الجملة الطويلة نفسها
          for (var i = 0; i < sentence.length; i += maxLength) {
            final end = (i + maxLength < sentence.length)
                ? i + maxLength
                : sentence.length;
            chunks.add(sentence.substring(i, end));
          }
          buffer.clear();
        }
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    return chunks;
  }

  /// هل يتم النطق حالياً
  static bool get isSpeaking => _isSpeaking;

  /// هل الخدمة مدعومة
  static bool get isSupported => kIsWeb || !Platform.isWindows;

  /// تحرير الموارد
  static Future<void> dispose() async {
    await stop();
  }
}
