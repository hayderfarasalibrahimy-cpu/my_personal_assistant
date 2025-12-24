import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

import 'package:speech_to_text/speech_recognition_error.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  Function(String status)? _onStatus; // مضاف لمتابعة حالة الاستماع الحالية
  Function(SpeechRecognitionError error)? _onError; // مضاف لمتابعة الأخطاء

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// تهيئة محرك التعرف على الصوت
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('STT Error: $error');
          _onError?.call(error); // إبلاغ المستمع بالخطأ
          _isListening = false;
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          _onStatus?.call(status); // إبلاغ المستمع بتغيير الحالة
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          } else if (status == 'listening') {
            _isListening = true;
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('STT Initialization Failed: $e');
      return false;
    }
  }

  /// بدء الاستماع
  /// [onResult] هي دالة الاستدعاء التي ستعيد النص المعترف به (جزئي أو نهائي)
  Future<void> listen({
    required Function(String text, bool isFinal) onResult,
    Function(String status)? onStatus,
    Function(SpeechRecognitionError error)? onError,
    String localeId = 'ar-SA', // العربية - السعودية كلمفضلة
  }) async {
    _onStatus = onStatus; // تخزين المستمع للجلسة الحالية
    _onError = onError; // تخزين مستمع الأخطاء
    if (!_isInitialized) {
      bool init = await initialize();
      if (!init) return;
    }

    // التحقق من أن الخدمة ليست قيد الاستماع بالفعل
    if (_speech.isListening) {
      debugPrint('STT: Already listening, skipping new session');
      return;
    }

    // التأكد من إيقاف أي جلسة سابقة لتجنب تضارب الحالات
    if (_isListening) {
      await _speech.stop();
      // انتظار قصير للتأكد من اكتمال الإيقاف
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          cancelOnError: false, // لا نوقف عند الخطأ
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
        // مدة الاستماع القصوى: 5 دقائق (الحد الأقصى للأجهزة)
        listenFor: const Duration(minutes: 5),
        // مدة الصمت: 30 ثانية قبل التوقف التلقائي
        pauseFor: const Duration(seconds: 30),
      );
    } catch (e) {
      debugPrint('STT Listen Failed: $e');
      _isListening = false;
    }
  }

  /// إيقاف الاستماع
  Future<void> stop() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      debugPrint('STT Stop Failed: $e');
    }
  }

  /// إلغاء الاستماع (بدون معالجة النتائج المتبقية)
  Future<void> cancel() async {
    try {
      await _speech.cancel();
      _isListening = false;
    } catch (e) {
      debugPrint('STT Cancel Failed: $e');
    }
  }
}
