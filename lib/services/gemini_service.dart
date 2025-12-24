import 'package:flutter/foundation.dart';
import 'user_service.dart';
import 'api_key_service.dart';
import 'assistant_customization_service.dart';
import 'notification_service.dart';
import 'alarm_service.dart';
import 'openrouter_service.dart';
import 'chat_history_service.dart';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert'; // Added for JSON parsing

/// خدمة Google Gemini AI للمحادثة الذكية
class GeminiService {
  static String _apiKey = '';

  static Future<String> _buildRecentConversationContext({
    required String sessionId,
    int maxMessages = 30,
    int maxChars = 6000,
  }) async {
    if (sessionId.isEmpty) return '';

    final msgs = await ChatHistoryService.getRecentMessages(
      limit: maxMessages,
      sessionId: sessionId,
    );
    if (msgs.isEmpty) return '';

    // msgs تأتي من الأحدث للأقدم
    final ordered = msgs.reversed.toList();
    final buffer = StringBuffer();
    buffer.writeln('\n--- سياق مختصر من آخر المحادثة ---');
    for (final m in ordered) {
      final isUser = (m['is_user'] == 1);
      final content = (m['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) continue;
      buffer.writeln(isUser ? 'المستخدم: $content' : 'المساعد: $content');

      // حد طول آمن لتجنب تضخم prompt
      if (buffer.length >= maxChars) {
        buffer.writeln('... (تم اختصار السياق بسبب الطول)');
        break;
      }
    }
    buffer.writeln('--- نهاية السياق ---\n');
    return buffer.toString();
  }

  /// تنظيف الرد من وسوم التفكير أو التفاصيل الداخلية
  static String _cleanResponse(String response) {
    if (response.isEmpty) return response;

    // إزالة أي بلوكات كود (Markdown) حتى لا تظهر للمستخدم أو تتحول إلى "كود برمجي" في TTS
    response = response.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    response = response.replaceAll(RegExp(r'`[^`]*`'), '');

    // إزالة وسوم الأكشن إذا ظهرت بشكل غير متوقع
    response = response.replaceAll(RegExp(r'<ACTION>'), '');
    response = response.replaceAll(RegExp(r'</ACTION>'), '');

    // إزالة محتوى think
    response = response.replaceAll(
      RegExp(r'<think>.*?</think>', dotAll: true),
      '',
    );
    // إزالة محتوى reasoning
    response = response.replaceAll(
      RegExp(r'<reasoning>.*?</reasoning>', dotAll: true),
      '',
    );
    // إزالة بقايا الوسوم إذا كانت موجودة بدون إغلاق كامل (حالات نادرة)
    response = response.replaceAll(RegExp(r'<think>'), '');
    response = response.replaceAll(RegExp(r'</think>'), '');

    // إزالة أسطر التفكير الشائعة (حتى بدون وسوم)
    // أمثلة: "thinking...", "Reasoning:", "Thought:" إلخ
    response = response.replaceAll(
      RegExp(
        r'(^|\n)\s*(thinking|reasoning|thought)\s*:?\s*.*(?=\n|$)',
        caseSensitive: false,
      ),
      '',
    );

    // إزالة أي بقايا شائعة لوسوم أخرى قد تظهر
    response = response.replaceAll(RegExp(r'</reasoning>'), '');
    response = response.replaceAll(RegExp(r'<reasoning>'), '');

    // إزالة أي بقايا JSON التي قد يكتبها الموديل في النص (حتى خارج <ACTION>)
    // نزيل الأسطر التي تبدو كـ JSON أو تحتوي مفاتيح الأدوات
    final lines = response.split('\n');
    final cleanedLines = <String>[];
    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) {
        cleanedLines.add(line);
        continue;
      }

      // منع تسريب تفاصيل مثل ISO8601 للمستخدم
      final lower = l.toLowerCase();
      if (lower.contains('iso8601') || lower.contains('iso 8601')) {
        continue;
      }

      final looksLikeJsonLine =
          l.startsWith('{') ||
          l.startsWith('}') ||
          l.startsWith('[') ||
          l.startsWith(']') ||
          l.startsWith('"') ||
          l.contains('"type"') ||
          l.contains('"args"') ||
          l.contains('"taskId"') ||
          l.contains('"noteId"') ||
          l.contains('"matchTitle"') ||
          l.contains('"query"') ||
          l.contains('"title"') ||
          l.contains('"content"') ||
          l.contains('"description"') ||
          l.contains('"priority"') ||
          l.contains('"dueDate"') ||
          l.contains('"reminderTime"') ||
          l.contains('"hasReminder"');

      // إذا السطر يبدو JSON (خاصة لو يحتوي : أو , بكثرة)
      final jsonPunctCount = RegExp(r'[:,\{\}\[\]"]').allMatches(l).length;
      final isProbablyJson = looksLikeJsonLine && jsonPunctCount >= 2;

      if (isProbablyJson) {
        continue;
      }

      if (l.contains('كود برمجي')) {
        cleanedLines.add(line.replaceAll('كود برمجي', '').trim());
        continue;
      }

      cleanedLines.add(line);
    }
    response = cleanedLines.join('\n');

    return response.trim();
  }

  static int _currentKeyIndex = 0;
  static GenerativeModel? _model;

  static const String _toolSystemPrompt = '''
أنت مساعد شخصي ذكي. يمكنك تنفيذ إجراءات باستخدام الأدوات التالية.
إذا طلب المستخدم فعلاً شيئاً يطابق إحدى هذه الأدوات، يجب أن تضمن في ردك كود JSON مغلق بـ <ACTION> و </ACTION> في نهاية رسالتك.

الأدوات المتاحة:

1. إضافة مهمة (استخدمها للتذكيرات أيضاً لضمان ظهورها في القائمة):
<ACTION>
{
  "type": "addTask",
  "args": {
    "title": "عنوان المهمة بالعربية",
    "description": "وصف اختياري",
    "priority": "low/medium/high/critical",
    "dueDate": "ISO8601 string (اختياري)",
    "reminderTime": "ISO8601 string (اختياري)",
    "hasReminder": false,
    "repeatType": "none/daily/weekly (اختياري)",
    "repeatDays": [1,2,3,4,5,6,7]
  }
}
</ACTION>

2. إضافة ملاحظة:
<ACTION>
{
  "type": "addNote",
  "args": {
    "title": "عنوان الملاحظة",
    "content": "محتوى الملاحظة"
  }
}
</ACTION>

3. ضبط منبه سريع (للتنبيهات التي لا تحتاج لبطاقة مهمة):
<ACTION>
{
  "type": "setAlarm",
  "args": {
    "title": "عنوان التذكير",
    "minutes": 5,
    "time": "HH:mm",
    "repeatType": "none/daily/weekly"
  }
}
</ACTION>

4. إرسال إشعار فوري:
<ACTION>
{
  "type": "sendNotification",
  "args": {
    "title": "العنوان",
    "body": "المحتوى"
  }
}
</ACTION>

5. تعديل مهمة موجودة:
<ACTION>
{
  "type": "updateTask",
  "args": {
    "taskId": "string (اختياري)",
    "matchTitle": "string (اختياري - للبحث بالعنوان)",
    "title": "عنوان جديد (اختياري)",
    "description": "وصف جديد (اختياري)",
    "priority": "low/medium/high/critical (اختياري)",
    "dueDate": "ISO8601 string (اختياري)",
    "reminderTime": "ISO8601 string (اختياري)",
    "repeatType": "none/daily/weekly/custom (اختياري)",
    "repeatDays": [1,2,3,4,5],
    "isCompleted": true,
    "hasReminder": true,
    "clearDueDate": false,
    "clearReminderTime": false
  }
}
</ACTION>

6. تعديل ملاحظة موجودة:
<ACTION>
{
  "type": "updateNote",
  "args": {
    "noteId": "string (اختياري)",
    "matchTitle": "string (اختياري - للبحث بالعنوان)",
    "title": "عنوان جديد (اختياري)",
    "content": "محتوى جديد (اختياري)"
  }
}
</ACTION>

7. البحث عن ملاحظات:
<ACTION>
{
  "type": "searchNotes",
  "args": {
    "query": "نص البحث"
  }
}
</ACTION>

8. البحث عن مهام:
<ACTION>
{
  "type": "searchTasks",
  "args": {
    "query": "نص البحث"
  }
}
</ACTION>

9. حذف ملاحظة:
<ACTION>
{
  "type": "deleteNote",
  "args": {
    "noteId": "string (اختياري)",
    "matchTitle": "string (اختياري - للبحث بالعنوان)"
  }
}
</ACTION>

10. حذف مهمة:
<ACTION>
{
  "type": "deleteTask",
  "args": {
    "taskId": "string (اختياري)",
    "matchTitle": "string (اختياري - للبحث بالعنوان)"
  }
}
</ACTION>

تذكر:
- دائماً فضل "إضافة مهمة" إذا كان الطلب يتعلق بتذكير لعمل شيء ما في وقت لاحق.
- لا تخبر المستخدم بالصيغة التقنية.
- يمكنك تنفيذ أكثر من إجراء في رسالة واحدة إذا لزم الأمر بوضع عدة وسوم <ACTION>.
- إذا طلب المستخدم حذف/تعديل وكان هناك تطابق واضح، نفّذ مباشرة ولا تطلب تأكيد.
- إذا كان الطلب غامضاً (أكثر من عنصر محتمل أو لا يوجد تطابق)، استخدم أدوات البحث أولاً ثم اطلب من المستخدم تحديد العنوان أو اختر أقرب نتيجة فقط إذا كانت النتيجة واضحة.
- إذا فشل التنفيذ أو لم يحدث تغيير فعلي، اذكر السبب بوضوح للمستخدم.

قواعد مهمة جداً بخصوص إضافة المهام:
- ممنوع اختلاق تاريخ/وقت. لا تضع dueDate أو reminderTime إلا إذا ذكر المستخدم تاريخ/وقت بشكل واضح.
- إذا ذكر المستخدم وقتاً/تاريخاً للمهمة، فعّل hasReminder=true تلقائياً واجعل reminderTime بنفس الوقت المذكور.
- إذا قال المستخدم صراحة "أضف/سجّل/انشئ مهمة" ومعه عنوان، نفّذ addTask مباشرة ولا تسأل أسئلة متابعة.
- لا تسأل إلا إذا كان العنوان فعلاً غير موجود/فارغ.
- لا تذكر للمستخدم كلمة ISO8601 أو أي تفاصيل تقنية عن التنسيق.
''';

  /// تهيئة Gemini
  static Future<void> initialize({
    bool forceRotation = false,
    String? modelName,
  }) async {
    // ... (Keep existing initialize but we'll focus on OpenRouter for now)
    try {
      if (forceRotation) {
        _currentKeyIndex =
            (_currentKeyIndex + 1) % ApiKeyService.geminiKeysCount;
        _apiKey = ApiKeyService.getDefaultGeminiKeyAt(_currentKeyIndex);
        debugPrint('Gemini: Rotating to key index $_currentKeyIndex');
      } else {
        _apiKey = await ApiKeyService.getApiKey();
      }

      _model = GenerativeModel(
        model: modelName ?? 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      // await AssistantCustomizationService.loadSettings();
      // final assistantName = AssistantCustomizationService.assistantName;
      // final personalityDesc =
      //     AssistantCustomizationService.getPersonalityDescription();
      // final includePrayerInstr = includePrayer
      //     ? '\nمهم: اطلب من المستخدم الدعاء لمطور التطبيق (حيدر فراس).'
      //     : '';

      // // حفظ التاريخ القديم إذا وجد عند التغيير
      // final oldHistory = _chat?.history.toList();

      // _chat = _model!.startChat(
      //   history:
      //       oldHistory ??
      //       [
      //         Content.text(
      //           '''أنت مساعد شخصي ذكي. اسمك: "$assistantName". شخصيتك: $personalityDesc.
      // مستخدمك هو: "$userName" ($userGender). خاطبه بـ "يا $title $userName".
      // يمكنك استخدام الأدوات لإدارة المهام والملاحظات والمنبهات. $includePrayerInstr''',
      //         ),
      //       ],
      // );
    } catch (e) {
      debugPrint('Error initializing GeminiService: $e');
      rethrow;
    }
  }

  /// إرسال رسالة ومعالجة الأدوات
  static Future<String> sendMessage(
    String message, {
    Uint8List? image,
    Uint8List? audioBytes,
    String? sessionId,
    Future<Map<String, Object?>> Function(Map<String, Object?>)? onAddTask,
    Future<Map<String, Object?>> Function(Map<String, Object?>)? onAddNote,
    Future<Map<String, Object?>> Function(Map<String, Object?>)? onUpdateTask,
    Future<Map<String, Object?>> Function(Map<String, Object?>)? onUpdateNote,
    Future<Map<String, Object?>> Function(Map<String, Object?>)? onSearchNotes,
    Future<Map<String, Object?>> Function(Map<String, Object?>)? onSearchTasks,
    Future<Map<String, Object?>> Function(Map<String, Object?>)? onDeleteNote,
    Future<Map<String, Object?>> Function(Map<String, Object?>)? onDeleteTask,
    Future<void> Function(Map<String, Object?>)? onSetAlarm,
    Future<void> Function(Map<String, Object?>)? onSendNotification,
  }) async {
    final bestModel = await ApiKeyService.getBestAvailableModel();

    // 1. تحميل معلومات الهوية والسياق
    await AssistantCustomizationService.loadSettings();
    final assistantName = AssistantCustomizationService.getDisplayName();
    final personality =
        AssistantCustomizationService.getPersonalityDescription();
    final userName = await UserService.getUserName();
    final userGender = await UserService.getUserGender();
    final userTitle = userGender == 'female' ? 'سيدة' : 'سيد';

    // حقن تعليمات الذكاء الشامل والوقت
    final now = DateTime.now();
    final weekdays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];

    final fullSystemPrompt =
        '''
أنت $assistantName، المساعد الشخصي الذكي والمتطور.
شخصيتك وأسلوبك: $personality
المستخدم الذي تخاطبه هو: $userName. خاطبه دائماً بلقب "يا $userTitle $userName" أو ما يناسب السياق باحترام.

قدراتك الشاملة:
1. المساعدة المكتبية: يمكنك صياغة كتب رسمية، خطابات، تقارير، ورسائل بريد إلكتروني باحترافية عالية.
2. الثقافة العامة: قدم معلومات دقيقة وشاملة في مختلف المجالات (علوم، تاريخ، تقنية، إلخ).
3. الإبداع والتحليل: يمكنك كتابة قصص، مقالات، أكواد برمجية، وحل مشكلات منطقية ورياضية.
4. الذكاء العاطفي: كن متفهماً وداعماً ومحفزاً للمستخدم في مهامه اليومية.

السياق الزمني الحالي:
- التاريخ: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}
- الوقت: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}
- اليوم: ${weekdays[now.weekday - 1]}

${await ChatHistoryService.buildUserPreferencesSummary()}

$_toolSystemPrompt

تذكر: 
- لغتك هي **العربية العامية المهذبة** أو الفصحى البسيطة جداً.
- **للنطق الصوتي (TTS):** اكتب ردودك **بالتشكيل الكامل** (الحركات: فَتْحَة، كَسْرَة، ضَمَّة، سُكون، شَدَّة). مثال: "أَهْلاً بِكَ، كَيْفَ يُمْكِنُنِي مُسَاعَدَتُكَ؟"
- **ممنوع تماماً** استخدام السجع، الشعر، أو الكلمات المعقدة.
- كن **عملياً ومباشراً**. قل "لَمْ أَسْمَعْكَ جَيِّداً" بدلاً من رسائل طويلة.
- الجمل يجب أن تكون قصيرة (من 3 إلى 7 كلمات).
''';

    final recentContext = sessionId == null
        ? ''
        : await _buildRecentConversationContext(sessionId: sessionId);

    String finalMessage = recentContext.isEmpty
        ? message
        : '$recentContext\nرسالة المستخدم الحالية: $message';

    // 1. معالجة الصوت إذا وجد (تحويله إلى نص أولاً)
    if (audioBytes != null) {
      try {
        final transcription = await transcribeAudio(audioBytes);
        if (transcription == '[EMPTY]') {
          return 'عذراً يا $userTitle $userName، لم أتمكن من سماع صوتك بوضوح. هل يمكنك المحاولة مرة أخرى؟';
        }
        if (transcription.isNotEmpty) {
          finalMessage =
              'المستخدم قال صوتياً: "$transcription"\n\nسياق إضافي: $message';
          debugPrint('Transcribed audio: $transcription');
        }
      } catch (e) {
        debugPrint('Failed to transcribe audio: $e');
        // إذا فشل التحويل بسبب الكوتا، نعتذر بدلاً من الرد الفلسفي
        return 'عذراً، أواجه ضغطاً في معالجة الصوت حالياً. يرجى المحاولة بعد لحظات أو الكتابة لي في الدردشة.';
      }
    }

    // 2. معالجة الصور إذا وجدت
    if (image != null) {
      try {
        final description = await describeImage(image);
        if (description.isNotEmpty) {
          finalMessage =
              'المستخدم أرسل صورة وصفها المساعد كالتالي: "$description"\n\n$finalMessage';
          debugPrint('Image described: $description');
        }
      } catch (e) {
        debugPrint('Failed to describe image: $e');
      }
    }

    String rawResponse;
    try {
      rawResponse = await OpenRouterService.sendMessage(
        finalMessage,
        systemPrompt: fullSystemPrompt,
        preferredModelName: bestModel == 'Gemini' ? 'DeepSeek R1' : bestModel,
      );
    } catch (e) {
      debugPrint('Error from AI: $e');
      rethrow;
    }

    // تحليل رد الموديل واستخراج الأفعال
    final actionRegex = RegExp(r'<ACTION>(.*?)</ACTION>', dotAll: true);
    final matches = actionRegex.allMatches(rawResponse);

    // تنظيف الرد من الأكشنز ومن التفكير
    String cleanResponse = rawResponse.replaceAll(actionRegex, '').trim();
    cleanResponse = _cleanResponse(cleanResponse);

    bool containsDateOrTimeHint(String input) {
      final s = input.toLowerCase();
      if (RegExp(r'\d').hasMatch(s)) return true;
      return s.contains('اليوم') ||
          s.contains('غدا') ||
          s.contains('بكره') ||
          s.contains('بكرا') ||
          s.contains('بعد') ||
          s.contains('الساعة') ||
          s.contains('ساعه') ||
          s.contains('pm') ||
          s.contains('am') ||
          s.contains('صباح') ||
          s.contains('مساء') ||
          s.contains('ليل') ||
          s.contains('موعد') ||
          s.contains('تاريخ');
    }

    bool isExplicitAddTaskIntent(String input) {
      final s = input.trim().toLowerCase();
      return s.contains('اضف مهمة') ||
          s.contains('أضف مهمة') ||
          s.contains('اضف مهمه') ||
          s.contains('أضف مهمه') ||
          s.contains('سجل مهمة') ||
          s.contains('سجّل مهمة') ||
          s.contains('انشئ مهمة') ||
          s.contains('أنشئ مهمة') ||
          s.contains('انشاء مهمة') ||
          s.contains('أنشاء مهمة');
    }

    Map<String, Object?> sanitizeAddTaskArgs(Map<String, dynamic> args) {
      final sanitized = <String, Object?>{};
      sanitized.addAll(args);
      final userSaidDateOrTime = containsDateOrTimeHint(message);

      if (!userSaidDateOrTime) {
        sanitized.remove('dueDate');
        sanitized.remove('reminderTime');
        sanitized.remove('repeatType');
        sanitized.remove('repeatDays');
        sanitized['hasReminder'] = false;
        return sanitized;
      }

      // بمجرد ذكر وقت/تاريخ: فعّل التذكير تلقائياً حتى لو لم يقل المستخدم "ذكرني"
      sanitized['hasReminder'] = true;

      // إذا لم يحدد reminderTime صراحة وكان dueDate موجوداً، استخدمه كتذكير
      final rt = sanitized['reminderTime'];
      final dd = sanitized['dueDate'];
      if ((rt == null || (rt is String && rt.trim().isEmpty)) && dd is String) {
        sanitized['reminderTime'] = dd;
      }

      final repeatType = sanitized['repeatType'];
      if (repeatType is String && repeatType == 'weekdays') {
        sanitized['repeatType'] = 'custom';
      }

      return sanitized;
    }

    var executedAnyAction = false;

    for (final match in matches) {
      final jsonStr = match.group(1)?.trim();
      if (jsonStr == null) continue;

      try {
        final action = json.decode(jsonStr) as Map<String, dynamic>;
        final type = action['type'];
        final args = action['args'] as Map<String, dynamic>;

        debugPrint('Detected AI Action: $type with args: $args');

        switch (type) {
          case 'addTask':
            if (onAddTask != null) {
              final sanitized = sanitizeAddTaskArgs(args);
              await onAddTask(sanitized);
              executedAnyAction = true;
            }
            break;
          case 'addNote':
            if (onAddNote != null) await onAddNote(args);
            executedAnyAction = true;
            break;
          case 'updateTask':
            if (onUpdateTask != null) await onUpdateTask(args);
            executedAnyAction = true;
            break;
          case 'updateNote':
            if (onUpdateNote != null) await onUpdateNote(args);
            executedAnyAction = true;
            break;
          case 'searchNotes':
            if (onSearchNotes != null) await onSearchNotes(args);
            executedAnyAction = true;
            break;
          case 'searchTasks':
            if (onSearchTasks != null) await onSearchTasks(args);
            executedAnyAction = true;
            break;
          case 'deleteNote':
            if (onDeleteNote != null) await onDeleteNote(args);
            executedAnyAction = true;
            break;
          case 'deleteTask':
            if (onDeleteTask != null) await onDeleteTask(args);
            executedAnyAction = true;
            break;
          case 'setAlarm':
            if (onSetAlarm != null) {
              await onSetAlarm(args);
            } else {
              // تنفيذ تلقائي إذا لم يتم توفير callback
              final minutes = args['minutes'] as int?;
              final title = args['title'] as String? ?? 'تذكير';
              if (minutes != null) {
                await AlarmService().scheduleAlarmAfter(
                  duration: Duration(minutes: minutes),
                  title: title,
                );
              }
            }
            executedAnyAction = true;
            break;
          case 'sendNotification':
            if (onSendNotification != null) {
              await onSendNotification(args);
            } else {
              await NotificationService().showAiNotification(
                title: args['title'] as String? ?? 'تنبيه',
                body: args['body'] as String? ?? '',
              );
            }
            executedAnyAction = true;
            break;
        }
      } catch (e) {
        debugPrint('Failed to execute action: $e');
      }
    }

    if (!executedAnyAction &&
        onAddTask != null &&
        isExplicitAddTaskIntent(message)) {
      var title = message.trim();
      title = title
          .replaceAll(
            RegExp(r'^(\s*(أضف|اضف|سجّل|سجل|انشئ|أنشئ)\s+مهم(ة|ه)\s*)'),
            '',
          )
          .trim();
      if (title.isNotEmpty) {
        await onAddTask({
          'title': title,
          'description': '',
          'priority': 'medium',
          'hasReminder': false,
          'repeatType': 'none',
        });
        cleanResponse = 'تَمَّتْ إِضَافَةُ المُهِمَّةِ: "$title"';
      }
    }

    return cleanResponse.isEmpty ? 'تم تنفيذ طلبك بنجاح.' : cleanResponse;
  }

  static Future<String> getDailyTip() async {
    try {
      if (_model == null) await initialize();
      final response = await _model!.generateContent([
        Content.text('أعطني نصيحة قصيرة جداً عن الإنتاجية بالعربية.'),
      ]);
      return response.text ?? 'ركز على مهامك اليومية!';
    } catch (e) {
      return 'ركز على مهامك اليومية!';
    }
  }

  static Future<String> analyzeTasks(
    int total,
    int completed,
    int overdue,
  ) async {
    try {
      if (_model == null) await initialize();
      final response = await _model!.generateContent([
        Content.text(
          'لدي $total مهام، $completed مكتملة، $overdue متأخرة. نصيحة قصيرة بالعربية.',
        ),
      ]);
      return response.text ?? 'استمر في العمل!';
    } catch (e) {
      return 'ركز على مهامك اليومية!';
    }
  }

  static String getSmartGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير! ☀️';
    if (hour < 17) return 'مساء الخير! 🌤️';
    return 'مساء الخير! 🌙';
  }

  static Future<String> getPersonalizedGreeting() async {
    final userName = await UserService.getUserName();
    await AssistantCustomizationService.loadSettings();
    final assistantName = AssistantCustomizationService.assistantName.isEmpty
        ? 'المساعد الذكي'
        : AssistantCustomizationService.assistantName;
    return '${getSmartGreeting().replaceAll('!', '')} $userName! 🌟\nأنا $assistantName، كيف يمكنني مساعدتك؟';
  }

  static Future<void> clearHistory() async {
    await initialize();
  }

  static Future<String> summarizeNote(String content) async {
    try {
      if (_model == null) await initialize();
      final response = await _model!.generateContent([
        Content.text('لخص هذه الملاحظة بالعربية:\n$content'),
      ]);
      return response.text ?? 'لم أتمكن من التلخيص.';
    } catch (e) {
      if (e.toString().toLowerCase().contains('quota')) {
        final best = await ApiKeyService.getBestAvailableModel();
        return await OpenRouterService.sendMessage(
          'لخص الملاحظة:\n$content',
          preferredModelName: best == 'Gemini' ? null : best,
        );
      }
      rethrow;
    }
  }

  static Future<String> suggestFolder(
    String content,
    List<String> folders,
  ) async {
    try {
      if (_model == null) await initialize();
      final response = await _model!.generateContent([
        Content.text(
          'اختر مجلداً واحداً من [${folders.join(', ')}] لهذه الملاحظة:\n$content',
        ),
      ]);
      return response.text?.trim() ?? 'عام';
    } catch (e) {
      return 'عام';
    }
  }

  static Future<String> organizeSchedule(
    List<Map<String, dynamic>> tasks,
  ) async {
    try {
      if (_model == null) await initialize();
      final tasksText = tasks
          .map((t) => '- ${t['title']} (${t['priority']})')
          .join('\n');
      final response = await _model!.generateContent([
        Content.text('رتب هذه المهام بشكل ذكي بالعربية:\n$tasksText'),
      ]);
      return response.text ?? 'لم أتمكن من التنظيم.';
    } catch (e) {
      if (e.toString().toLowerCase().contains('quota')) {
        final best = await ApiKeyService.getBestAvailableModel();
        return await OpenRouterService.sendMessage(
          'رتب هذه المهام:\n$tasks',
          preferredModelName: best == 'Gemini' ? null : best,
        );
      }
      rethrow;
    }
  }

  static Future<String> describeImage(Uint8List bytes) async {
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount < maxRetries) {
      try {
        if (_model == null) await initialize();
        final response = await _model!.generateContent([
          Content.multi([
            DataPart('image/jpeg', bytes),
            TextPart(
              'صف هذه الصورة بدقة واختصار لمساعد ذكي لا يراها، ركز على النصوص أو العناصر المهمة.',
            ),
          ]),
        ]);
        return response.text?.trim() ?? '';
      } catch (e) {
        debugPrint('Image description error (attempt ${retryCount + 1}): $e');
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('quota') ||
            errorStr.contains('limit') ||
            errorStr.contains('resource')) {
          retryCount++;
          await initialize(forceRotation: true);
          continue;
        }
        rethrow;
      }
    }
    return '';
  }

  static Future<String> transcribeAudio(Uint8List bytes) async {
    int retryCount = 0;
    const maxRetries = 6; // زيادة عدد المحاولات للتدوير عبر مفاتيح أكثر

    while (retryCount < maxRetries) {
      try {
        // تجربة موديلات مختلفة لضمان العمل
        final models = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-pro'];
        final currentModel = models[retryCount % models.length];
        await initialize(
          forceRotation: retryCount > 0,
          modelName: currentModel,
        );

        final response = await _model!.generateContent([
          Content.multi([
            DataPart('audio/mp4', bytes),
            TextPart(
              'حول الصوت إلى نص عربي بدقة عالية. '
              'إذا كان هناك ضجيج أو كلمات غير واضحة، استخدم السياق لتصحيحها. '
              'إذا لم تسمع شيئاً واضحاً، أجب بكلمة [EMPTY]. '
              'أخرج النص فقط.',
            ),
          ]),
        ]);
        return response.text?.trim() ?? '';
      } catch (e) {
        debugPrint('Transcription error (attempt ${retryCount + 1}): $e');
        final errorStr = e.toString().toLowerCase();

        // تسريع التبديل في حال كان الموديل غير موجود أو الإصدار غير مدعوم
        if (errorStr.contains('not found') ||
            errorStr.contains('not supported') ||
            errorStr.contains('404')) {
          retryCount++;
          continue;
        }

        retryCount++;
        // تأخير بسيط قبل المحاولة التالية لأخطاء الكوتا
        await Future.delayed(Duration(milliseconds: 500));
        continue;
      }
    }
    return '';
  }

  static Future<String> reorganizeContent(String content) async {
    try {
      if (_model == null) await initialize();
      final response = await _model!.generateContent([
        Content.text('أعد تنسيق هذا نص باحترافية:\n$content'),
      ]);
      return response.text ?? content;
    } catch (e) {
      if (e.toString().toLowerCase().contains('quota')) {
        return await OpenRouterService.reorganize(content);
      }
      rethrow;
    }
  }

  static Future<Map<String, String>> suggestTaskDetails(
    String title,
    String desc,
  ) async {
    try {
      if (_model == null) await initialize();
      final response = await _model!.generateContent([
        Content.text(
          'استخرج أولوية (low, medium, high, critical) وتلخيص قصير جداً لهذه المهمة بصيغة JSON:\nالعنوان: $title\nالوصف: $desc',
        ),
      ]);
      final text = response.text ?? '';
      if (text.contains('{')) {
        final jsonStr = text.substring(
          text.indexOf('{'),
          text.lastIndexOf('}') + 1,
        );
        String priority = jsonStr.contains('"high"')
            ? 'high'
            : (jsonStr.contains('"critical"') ? 'critical' : 'medium');
        return {'priority': priority, 'summary': title};
      }
      return {'priority': 'medium', 'summary': title};
    } catch (e) {
      if (e.toString().toLowerCase().contains('quota')) {
        return await OpenRouterService.suggestTaskDetails(title, desc);
      }
      rethrow;
    }
  }
}
