import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة مفتاح API الخاص بالمستخدم
class ApiKeyService {
  static const String _apiKeyKey = 'user_gemini_api_key';
  static String? _cachedApiKey;

  /// المفتاح الافتراضي (للتجربة فقط)
  /// المفاتيح الافتراضية (للتجربة ولفك الضغط عن الكوتا)
  static const List<String> defaultGeminiKeys = [
    'AIzaSyD_YiVChsT7ZCGgCJe5hSa-XG38VPf2_7k', // مفتاح جديد
    'AIzaSyBzOrvfwahjGOdE354ypWE-9Dcntk8_saE',
    'AIzaSyCqYH-HDkUfeawDg2-RMwLAwzqwF-J2W0A',
    'AIzaSyA_ix-sAQve-Dch_WgCMdHKhq9Fd9SBnLU',
    'AIzaSyAlIvWUG8wiifR4hq8hhbTVf3-ciHE0Pww',
    'AIzaSyAjKFyoE4Hk0wHdYlnDTXjSDeYgFNjkrCE',
    'AIzaSyC5CsmEpUNHO2B8AE6oDeN1JgyuCX-_vyg',
    'AIzaSyAZFYp004Sxxz5wmmK20PgCuWmcwSqw3ns',
    'AIzaSyA2J5v1r1O0APpCEcWn9LZcPUw_hSkKWqU',
    'AIzaSyAiyLtSU_XnVsBLeOM_jJcPIgQEdEyY7Ik',
    'AIzaSyAEvZ6E_kUEriZ8YwyXtRVhmlGgazqszhY',
    'AIzaSyAx1xe-eSl45XhuLPhmHrkYQ_Wvim51WGE',
    'AIzaSyArtXUnvcILN0eKmyX36B6bxB892wHYnpY',
    'AIzaSyAQJMRH7Fm6Xl7tEWUXDk-gD2bHVJ-ysQk',
  ];

  static const String defaultOpenRouterKey =
      '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';

  /// الحصول على مفتاح API المحفوظ
  static Future<String> getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_apiKeyKey);

    if (savedKey != null && savedKey.isNotEmpty) {
      _cachedApiKey = savedKey;
      return savedKey;
    }

    return defaultGeminiKeys.first;
  }

  /// الحصول على مفتاح محدد من القائمة الافتراضية (للتبديل)
  static String getDefaultGeminiKeyAt(int index) {
    if (index < 0 || index >= defaultGeminiKeys.length) {
      return defaultGeminiKeys.first;
    }
    return defaultGeminiKeys[index];
  }

  /// عدد المفاتيح الافتراضية المتاحة
  static int get geminiKeysCount => defaultGeminiKeys.length;

  /// حفظ مفتاح API جديد
  static Future<bool> saveApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyKey, apiKey);
      _cachedApiKey = apiKey;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// حذف مفتاح API المحفوظ (العودة للافتراضي)
  static Future<bool> clearApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKeyKey);
      _cachedApiKey = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// التحقق من وجود مفتاح مخصص
  static Future<bool> hasCustomApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_apiKeyKey);
    return savedKey != null && savedKey.isNotEmpty;
  }

  /// التحقق من صحة صيغة المفتاح
  static bool isValidApiKeyFormat(String apiKey) {
    // مفتاح Gemini يبدأ بـ AIza ويكون طوله حوالي 39 حرف
    return apiKey.startsWith('AIza') && apiKey.length >= 35;
  }

  // --- OpenRouter Keys (Multiple) ---
  static const String _openRouterKeysKey = 'user_openrouter_api_keys';
  static List<String>? _cachedOpenRouterKeys;
  static int _currentOpenRouterKeyIndex = 0;

  /// المفاتيح الافتراضية لـ OpenRouter (يمكن إضافة المزيد)
  static const List<String> defaultOpenRouterKeys = [
    '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',
    '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',
    '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',
    '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',
    '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',
  ];

  /// الحصول على قائمة مفاتيح OpenRouter
  static Future<List<String>> getOpenRouterKeys() async {
    if (_cachedOpenRouterKeys != null && _cachedOpenRouterKeys!.isNotEmpty) {
      return _cachedOpenRouterKeys!;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedKeys = prefs.getStringList(_openRouterKeysKey);
    if (savedKeys != null && savedKeys.isNotEmpty) {
      _cachedOpenRouterKeys = savedKeys;
      return savedKeys;
    }
    return defaultOpenRouterKeys;
  }

  /// الحصول على المفتاح الحالي (مع التدوير)
  static Future<String?> getOpenRouterKey() async {
    final keys = await getOpenRouterKeys();
    if (keys.isEmpty) return defaultOpenRouterKeys.first;
    return keys[_currentOpenRouterKeyIndex % keys.length];
  }

  /// التدوير للمفتاح التالي
  static Future<String> rotateOpenRouterKey() async {
    final keys = await getOpenRouterKeys();
    _currentOpenRouterKeyIndex = (_currentOpenRouterKeyIndex + 1) % keys.length;
    debugPrint(
      '🔄 OpenRouter Key rotated to index: $_currentOpenRouterKeyIndex',
    );
    return keys[_currentOpenRouterKeyIndex];
  }

  /// إضافة مفتاح OpenRouter جديد
  static Future<bool> addOpenRouterKey(String key) async {
    if (key.isEmpty || !key.startsWith('sk-or-')) return false;
    final prefs = await SharedPreferences.getInstance();
    final keys = await getOpenRouterKeys();
    if (!keys.contains(key)) {
      final newKeys = [...keys, key];
      await prefs.setStringList(_openRouterKeysKey, newKeys);
      _cachedOpenRouterKeys = newKeys;
      return true;
    }
    return false; // المفتاح موجود بالفعل
  }

  /// حذف مفتاح OpenRouter
  static Future<bool> removeOpenRouterKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await getOpenRouterKeys();
    if (keys.contains(key) && keys.length > 1) {
      final newKeys = keys.where((k) => k != key).toList();
      await prefs.setStringList(_openRouterKeysKey, newKeys);
      _cachedOpenRouterKeys = newKeys;
      _currentOpenRouterKeyIndex = 0;
      return true;
    }
    return false;
  }

  /// عدد مفاتيح OpenRouter المتاحة
  static Future<int> get openRouterKeysCount async {
    final keys = await getOpenRouterKeys();
    return keys.length;
  }

  /// حفظ مفتاح واحد (للتوافق مع الكود القديم)
  static Future<bool> saveOpenRouterKey(String key) async {
    return await addOpenRouterKey(key);
  }

  // --- DeepSeek Key ---
  static const String _deepSeekKey = 'user_deepseek_api_key';
  static String? _cachedDeepSeekKey;

  static Future<String?> getDeepSeekKey() async {
    if (_cachedDeepSeekKey != null) return _cachedDeepSeekKey;
    final prefs = await SharedPreferences.getInstance();
    _cachedDeepSeekKey = prefs.getString(_deepSeekKey);
    return _cachedDeepSeekKey;
  }

  static Future<bool> saveDeepSeekKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deepSeekKey, key);
    _cachedDeepSeekKey = key;
    return true;
  }

  // --- Mistral Key ---
  static const String _mistralKey = 'user_mistral_api_key';
  static String? _cachedMistralKey;

  static Future<String?> getMistralKey() async {
    if (_cachedMistralKey != null) return _cachedMistralKey;
    final prefs = await SharedPreferences.getInstance();
    _cachedMistralKey = prefs.getString(_mistralKey);
    return _cachedMistralKey;
  }

  static Future<bool> saveMistralKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mistralKey, key);
    _cachedMistralKey = key;
    return true;
  }

  // --- Unified Request Tracking (الكوتا الموحدة) ---
  static const String _countsMapKey = 'ai_request_counts_map';
  static const String _lastResetKey = 'last_quota_reset_unified';

  /// نوتيفاير لإخطار الواجهة بتحديث العدادات لحظياً
  static final ValueNotifier<int> updateNotifier = ValueNotifier<int>(0);

  /// الحصول على عدد الطلبات لنموذج معين
  static Future<int> getRequestCount(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetQuota(prefs);
    final countsJson = prefs.getString(_countsMapKey) ?? '{}';
    final Map<String, dynamic> counts = jsonDecode(countsJson);
    return counts[modelName] ?? 0;
  }

  /// زيادة عدد الطلبات لنموذج معين (لكل أنواع الطلبات)
  static Future<void> incrementRequestCount(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetQuota(prefs);
    final countsJson = prefs.getString(_countsMapKey) ?? '{}';
    final Map<String, dynamic> counts = jsonDecode(countsJson);
    counts[modelName] = (counts[modelName] ?? 0) + 1;
    await prefs.setString(_countsMapKey, jsonEncode(counts));
    await _recordLastRequestTime(modelName);

    // إخطار المستمعين بالتغيير
    updateNotifier.value++;
  }

  /// الحصول على توقيت آخر طلب (اختياري، يمكن توسيعه)
  static Future<String> getLastRequestTime(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_req_$modelName') ?? 'لا يوجد بيانات';
  }

  /// تسجيل توقيت الطلب
  static Future<void> _recordLastRequestTime(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toLocal().toString().split('.')[0];
    await prefs.setString('last_req_$modelName', now);
  }

  static Future<void> _checkAndResetQuota(SharedPreferences prefs) async {
    final lastReset = prefs.getInt(_lastResetKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // إعادة التعيين كل دقيقة لجميع النماذج لتوحيد النمط وضمان سلاسة العرض
    if (now - lastReset > 60000) {
      await prefs.setString(_countsMapKey, '{}');
      await prefs.setInt(_lastResetKey, now);
    }
  }

  // Legacy for Gemini (Backward compatibility if needed)
  static Future<int> getGeminiRequestCount() => getRequestCount('Gemini');
  static Future<void> incrementGeminiCount() => incrementRequestCount('Gemini');

  // --- Active Model Tracking ---
  // --- Active Model Tracking ---
  static const String _activeModelKey = 'active_ai_model';
  static String _activeModel = 'Gemini';

  static String get activeModel => _activeModel;

  static Future<void> loadActiveModel() async {
    final prefs = await SharedPreferences.getInstance();
    _activeModel = prefs.getString(_activeModelKey) ?? 'Gemini';
  }

  static Future<void> setActiveModel(String model) async {
    _activeModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeModelKey, model);
  }

  // --- Priority & Auto-Switching System ---
  static const String _priorityKey = 'model_priority_list';
  static List<String>? _cachedPriority;

  // قائمة النماذج الـ 8 المتاحة في التطبيق
  static const List<String> allModels = [
    'Gemini',
    'DeepSeek R1',
    'Mistral Devstral',
    'Llama 3.3 70B',
    'Gemma 3 12B',
    'Qwen 2.5 VL',
    'Kimi K2',
    'Mistral 7B',
  ];

  // حدود التكرار (Requests per minute) للنماذج المجانية
  static const Map<String, int> modelLimits = {
    'Gemini': 15,
    'DeepSeek R1': 10,
    'Mistral Devstral': 10,
    'Llama 3.3 70B': 10,
    'Gemma 3 12B': 10,
    'Qwen 2.5 VL': 10,
    'Kimi K2': 10,
    'Mistral 7B': 10,
  };

  /// الحصول على ترتيب الأولوية الحالي (المحفوظ أو الافتراضي)
  static Future<List<String>> getModelPriority() async {
    if (_cachedPriority != null) return _cachedPriority!;

    final prefs = await SharedPreferences.getInstance();
    final savedPriority = prefs.getStringList(_priorityKey);

    if (savedPriority != null) {
      // تنظيف القائمة: إزالة النماذج غير الموجودة وإضافة النماذج الجديدة
      final sanitizedList = savedPriority
          .where((m) => allModels.contains(m))
          .toList();

      // إضافة أي نماذج جديدة غير موجودة في القائمة المحفوظة
      for (var model in allModels) {
        if (!sanitizedList.contains(model)) {
          sanitizedList.add(model);
        }
      }

      // إذا تغيرت القائمة عن المحفوظة، نقوم بتحديث الحفظ
      if (sanitizedList.length != savedPriority.length ||
          !sanitizedList.every((element) => savedPriority.contains(element))) {
        await saveModelPriority(sanitizedList);
      }

      _cachedPriority = sanitizedList;
      return sanitizedList;
    }

    // الافتراضي (يبدأ من الأقوى حسب تفضيل المستخدم)
    _cachedPriority = List.from(allModels);
    return _cachedPriority!;
  }

  /// حفظ ترتيب أولوية جديد
  static Future<void> saveModelPriority(List<String> newPriority) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_priorityKey, newPriority);
    _cachedPriority = newPriority;
    updateNotifier.value++; // تحديث الواجهة إذا كان هناك مستمعين
  }

  /// التحقق من توفر النموذج بناءً على الكوتا
  static Future<bool> isModelAvailable(String modelName) async {
    final count = await getRequestCount(modelName);
    final limit = modelLimits[modelName] ?? 10;
    return count < limit;
  }

  /// البحث عن أفضل نموذج متاح للعمل
  static Future<String> getBestAvailableModel() async {
    final priority = await getModelPriority();
    for (final model in priority) {
      if (await isModelAvailable(model)) {
        return model;
      }
    }
    // إذا نفدت جميع الحصص، نعود للأول (سيظهر خطأ Quota المعتاد لاحقاً)
    return priority.first;
  }
}
