import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_key_service.dart';
import 'user_service.dart';
import 'assistant_customization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// كلاس لتخزين الردود المؤقتة
class _CachedResponse {
  final String response;
  final DateTime timestamp;
  _CachedResponse(this.response, this.timestamp);

  /// التحقق من صلاحية الـ Cache (صالح لمدة ساعة)
  bool get isValid => DateTime.now().difference(timestamp).inMinutes < 60;
}

/// خدمة OpenRouter للتواصل مع نماذج الذكاء الاصطناعي البديلة
/// تُستخدم كـ Fallback عند نفاد رصيد Gemini
/// مع دعم التخزين المؤقت والتدوير الذكي للاستخدام غير المحدود
class OpenRouterService {
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _keyModels = 'openrouter_models';

  /// التخزين المؤقت للردود (Cache)
  static final Map<String, _CachedResponse> _responseCache = {};
  static const int _maxCacheSize = 50;

  /// تنظيف الـ Cache القديم
  static void _cleanOldCache() {
    if (_responseCache.length > _maxCacheSize) {
      final oldKeys = _responseCache.entries
          .where((e) => !e.value.isValid)
          .map((e) => e.key)
          .toList();
      for (var key in oldKeys) {
        _responseCache.remove(key);
      }
      // إذا لا يزال ممتلئاً، احذف الأقدم
      if (_responseCache.length > _maxCacheSize) {
        final sortedEntries = _responseCache.entries.toList()
          ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
        for (int i = 0; i < _responseCache.length - _maxCacheSize + 10; i++) {
          _responseCache.remove(sortedEntries[i].key);
        }
      }
    }
  }

  /// إحصائيات الـ Cache
  static int get cacheHits => _cacheHits;
  static int _cacheHits = 0;

  // مفتاح التطبيق الافتراضي (سيُستخدم إذا لم يدخل المستخدم مفتاحه الخاص)
  static const String _defaultApiKey =
      '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';

  /// النماذج المتاحة بالترتيب الافتراضي
  /// النماذج المتاحة بالترتيب الافتراضي
  static List<String> _models = [
    'deepseek/deepseek-r1-0528:free',
    'mistralai/devstral-2512:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'google/gemma-3-12b-it:free',
    'qwen/qwen-2.5-vl-7b-instruct:free',
    'moonshotai/kimi-k2:free',
    'mistralai/mistral-7b-instruct:free',
  ];

  /// تحديث قائمة النماذج
  static Future<void> updateModels(List<String> newModels) async {
    if (newModels.isNotEmpty) {
      _models = newModels;
      await saveModels();
    }
  }

  /// الحصول على النماذج المتاحة حالياً
  static List<String> get availableModels => List.unmodifiable(_models);

  /// تحميل النماذج من التخزين
  static Future<void> loadModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModels = prefs.getStringList(_keyModels);
      if (savedModels != null && savedModels.isNotEmpty) {
        _models = savedModels;
      }
    } catch (e) {
      debugPrint('Error loading models: $e');
    }
  }

  /// حفظ النماذج في التخزين
  static Future<void> saveModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyModels, _models);
    } catch (e) {
      debugPrint('Error saving models: $e');
    }
  }

  /// جلب النماذج المجانية المتاحة من OpenRouter
  static Future<List<String>> fetchAvailableFreeModels() async {
    try {
      final response = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/models'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allModels = data['data'];

        // تصفية النماذج المجانية فقط
        final freeModels = allModels
            .where((m) => m['id'].toString().contains(':free'))
            .map((m) => m['id'].toString())
            .toList();

        if (freeModels.isNotEmpty) {
          _models = freeModels;
          await saveModels();
        }

        return freeModels;
      } else {
        throw 'فشل جلب النماذج: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
      return [];
    }
  }

  /// خريطة لربط الأسماء العربية بالمعرفات التقنية
  static const Map<String, String> modelMap = {
    'DeepSeek R1': 'deepseek/deepseek-r1-0528:free',
    'Mistral Devstral': 'mistralai/devstral-2512:free',
    'Llama 3.3 70B': 'meta-llama/llama-3.3-70b-instruct:free',
    'Gemma 3 12B': 'google/gemma-3-12b-it:free',
    'Qwen 2.5 VL': 'qwen/qwen-2.5-vl-7b-instruct:free',
    'Kimi K2': 'moonshotai/kimi-k2:free',
    'Mistral 7B': 'mistralai/mistral-7b-instruct:free',
    'Gemini Flash 2.0': 'google/gemini-2.0-flash-001',
  };

  /// التحقق من صحة نموذج معين عن طريق إرسال رسالة تجريبية
  static Future<bool> checkModelHealth(String modelName) async {
    if (!modelMap.containsKey(modelName)) return false;

    final modelId = modelMap[modelName]!;
    try {
      // إرسال رسالة قصيرة جداً للاختبار
      final response = await _callApi(
        modelId,
        'ping', // رسالة قصيرة
        systemPrompt: 'Respond with "pong" only.',
        modelDisplayName: modelName,
      );
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Health check failed for $modelName: $e');
      return false;
    }
  }

  /// الحصول على قائمة النماذج المدعومة (الأسماء)
  static List<String> get supportedModels => modelMap.keys.toList();

  /// الفهرس الحالي للنموذج المستخدم
  static int _currentModelIndex = 0;

  /// إعادة تعيين إلى النموذج الأول
  static void resetToFirstModel() {
    _currentModelIndex = 0;
  }

  /// الحصول على اسم النموذج الحالي بالعربية
  static String get currentModelName {
    switch (_currentModelIndex) {
      case 0:
        return 'DeepSeek R1';
      case 1:
        return 'Mistral Devstral';
      case 2:
        return 'Llama 3.3 70B';
      case 3:
        return 'Gemma 3 12B';
      case 4:
        return 'Qwen 2.5 VL';
      case 5:
        return 'Kimi K2';
      case 6:
        return 'Mistral 7B';
      default:
        return 'Gemini';
    }
  }

  /// إرسال رسالة إلى OpenRouter مع دعم اختيار نموذج محدد
  /// يستخدم التخزين المؤقت للردود المتكررة والتدوير الذكي بين النماذج
  static Future<String> sendMessage(
    String message, {
    String? systemPrompt,
    String? preferredModelName,
    bool useCache = true,
  }) async {
    // تنظيف الـ Cache القديم
    _cleanOldCache();

    // فحص الـ Cache أولاً (فقط للرسائل بدون System Prompt مخصص)
    if (useCache && systemPrompt == null) {
      final cacheKey = message.trim().toLowerCase().hashCode.toString();
      if (_responseCache.containsKey(cacheKey)) {
        final cached = _responseCache[cacheKey]!;
        if (cached.isValid) {
          _cacheHits++;
          debugPrint('📦 Cache hit! (Total: $_cacheHits)');
          return cached.response;
        }
      }
    }

    String? result;

    // إذا تم تحديد نموذج معين، نحاول استخدامه أولاً
    if (preferredModelName != null &&
        modelMap.containsKey(preferredModelName)) {
      final modelId = modelMap[preferredModelName]!;
      try {
        result = await _callApi(
          modelId,
          message,
          systemPrompt: systemPrompt,
          modelDisplayName: preferredModelName,
        );
        ApiKeyService.setActiveModel(preferredModelName);
      } catch (e) {
        debugPrint('OpenRouter: فشل النموذج المفضل $preferredModelName: $e');
        // إذا فشل، نستمر في المحاولة التلقائية أدناه
      }
    }

    // إذا نجح النموذج المفضل، نخزنه ونعيده
    if (result != null) {
      _cacheResult(message, result);
      return result;
    }

    // محاولة كل نموذج بالترتيب (Fallback)
    for (int attempt = 0; attempt < _models.length; attempt++) {
      final modelIndex = (_currentModelIndex + attempt) % _models.length;
      final modelId = _models[modelIndex];

      // العثور على الاسم المعروض لهذا الـ ID
      final displayName = modelMap.entries
          .firstWhere(
            (e) => e.value == modelId,
            orElse: () => const MapEntry('نموذج بديل', ''),
          )
          .key;

      try {
        result = await _callApi(
          modelId,
          message,
          systemPrompt: systemPrompt,
          modelDisplayName: displayName,
        );
        _currentModelIndex = modelIndex;
        ApiKeyService.setActiveModel(displayName);
        _cacheResult(message, result);
        return result;
      } catch (e) {
        debugPrint('OpenRouter: فشل النموذج $modelId: $e');
        if (attempt == _models.length - 1) {
          throw 'جميع النماذج البديلة غير متاحة حالياً. يرجى المحاولة لاحقاً.';
        }
      }
    }

    throw 'فشل الاتصال بجميع النماذج البديلة.';
  }

  /// تخزين النتيجة في الـ Cache
  static void _cacheResult(String message, String response) {
    final cacheKey = message.trim().toLowerCase().hashCode.toString();
    _responseCache[cacheKey] = _CachedResponse(response, DateTime.now());
  }

  /// الاستدعاء المباشر لـ API
  static Future<String> _callApi(
    String model,
    String message, {
    String? systemPrompt,
    String? modelDisplayName,
  }) async {
    final messages = <Map<String, String>>[];

    // الحصول على معلومات المستخدم والمساعد
    final userName = await UserService.getUserName();
    final userGender = await UserService.getUserGender();
    final title = userGender == 'female' ? 'سيدة' : 'سيد';

    await AssistantCustomizationService.loadSettings();
    final assistantName = AssistantCustomizationService.assistantName.isEmpty
        ? 'المساعد الذكي'
        : AssistantCustomizationService.assistantName;

    final contextPrompt =
        'أنت مساعد شخصي اسمك "$assistantName". '
        'تتحدث مع "$title $userName". ';

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': '$contextPrompt $systemPrompt',
      });
    } else {
      messages.add({'role': 'system', 'content': contextPrompt});
    }

    messages.add({'role': 'user', 'content': message});

    String? directKey;
    String apiUrl = _baseUrl;
    String authPrefix = 'Bearer ';

    // محاولة الحصول على مفاتيح مباشرة لكل نموذج
    if (model.contains('deepseek')) {
      directKey = await ApiKeyService.getDeepSeekKey();
      if (directKey != null && directKey.isNotEmpty) {
        apiUrl = 'https://api.deepseek.com/chat/completions';
      }
    } else if (model.contains('mistral')) {
      directKey = await ApiKeyService.getMistralKey();
      if (directKey != null && directKey.isNotEmpty) {
        apiUrl = 'https://api.mistral.ai/v1/chat/completions';
      }
    }

    final userKey = await ApiKeyService.getOpenRouterKey();
    final effectiveKey = (directKey != null && directKey.isNotEmpty)
        ? directKey
        : (userKey != null && userKey.isNotEmpty)
        ? userKey
        : _defaultApiKey;

    final response = await http
        .post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': '$authPrefix$effectiveKey',
            'Content-Type': 'application/json',
            if (apiUrl == _baseUrl) 'HTTP-Referer': 'https://mudhkira.app',
            if (apiUrl == _baseUrl) 'X-Title': 'Mudhkira - Life Organizer',
          },
          body: jsonEncode({
            'model': (directKey != null && directKey.isNotEmpty)
                ? (model.contains('deepseek')
                      ? 'deepseek-chat'
                      : 'mistral-small-latest')
                : model,
            'messages': messages,
            'max_tokens': 2048,
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw 'انتهت مهلة الاتصال بالخادم.';
          },
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'];

      if (content == null || content.toString().isEmpty) {
        throw 'الرد فارغ من الخادم.';
      }

      // تسجيل الطلب الناجح باستخدام الاسم المعروض
      if (modelDisplayName != null) {
        await ApiKeyService.incrementRequestCount(modelDisplayName);
      }
      return content.toString();
    } else if (response.statusCode == 429) {
      // تدوير المفتاح تلقائياً عند نفاد الحصة
      await ApiKeyService.rotateOpenRouterKey();
      throw 'نفد رصيد هذا المفتاح، جاري التبديل للمفتاح التالي...';
    } else {
      debugPrint(
        'AI Error ($apiUrl): ${response.statusCode} - ${response.body}',
      );

      final errorBody = response.body.toLowerCase();
      if (response.statusCode == 404 && errorBody.contains('data policy')) {
        throw 'يجب تفعيل خيار "Model Publication" في إعدادات OpenRouter لاستخدام هذا النموذج المجاني.';
      } else if (response.statusCode == 404) {
        throw 'النموذج غير متوفر حالياً أو المعرف غير صحيح.';
      }

      throw 'خطأ في الاتصال: ${response.statusCode}';
    }
  }

  /// تلخيص نص
  static Future<String> summarize(String content) async {
    const systemPrompt = '''أنت مساعد ذكي متخصص في تلخيص النصوص العربية.
قم بتلخيص النص المعطى في نقاط أساسية (3-5 نقاط) بلغة واضحة ومهنية.''';

    return sendMessage(
      'قم بتلخيص النص التالي:\n\n$content',
      systemPrompt: systemPrompt,
    );
  }

  /// إعادة تنظيم نص
  static Future<String> reorganize(String content) async {
    const systemPrompt = '''أنت مساعد ذكي متخصص في تنظيم وتنسيق النصوص العربية.
أعد تنظيم النص ليكون أكثر وضوحاً واحترافية مع الحفاظ على المعلومات الأساسية.''';

    return sendMessage(
      'أعد تنظيم النص التالي:\n\n$content',
      systemPrompt: systemPrompt,
    );
  }

  /// اقتراح أولوية للمهمة
  static Future<Map<String, String>> suggestTaskDetails(
    String title,
    String description,
  ) async {
    const systemPrompt = '''أنت مساعد ذكي لإدارة المهام.
بناءً على عنوان ووصف المهمة، اقترح الأولوية المناسبة.
أعد النتيجة بتنسيق JSON فقط: {"priority": "low/medium/high/critical", "summary": "ملخص قصير"}''';

    final response = await sendMessage(
      'العنوان: $title\nالوصف: $description',
      systemPrompt: systemPrompt,
    );

    try {
      // استخراج JSON من الرد
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return {
          'priority': json['priority']?.toString() ?? 'medium',
          'summary': json['summary']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint('Error parsing task details: $e');
    }

    return {'priority': 'medium', 'summary': ''};
  }
}
