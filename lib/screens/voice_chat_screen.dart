import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart'; // Lottie
import '../services/gemini_service.dart';
import '../services/stt_service.dart';

import '../services/tts_service.dart';
import '../services/chat_history_service.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../providers/task_provider.dart';
import '../providers/note_provider.dart';
import '../models/task.dart';
import '../models/note.dart';
import 'package:provider/provider.dart';
import '../utils/app_snackbar.dart';
import '../services/system_voice_service.dart';
import '../utils/text_utils.dart';

/// شاشة المحادثة الصوتية الاحترافية (بث مباشر)
class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  final SttService _sttService = SttService();

  String? _lastTaskId;
  String? _lastNoteId;

  // Show Dev Overlay initially
  bool _showDevOverlay = false;

  // حالات الشاشة
  VoiceChatState _state = VoiceChatState.idle;
  String _currentSpeech = ''; // النص الذي يتم التعرف عليه
  Timer? _stopListeningTimer; // مؤقت لإيقاف الاستماع عند الصمت

  // سجل المحادثات الصوتية
  final List<Map<String, String>> _conversationHistory = [];
  final ScrollController _historyScrollController = ScrollController();

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  // ألوان التدرج
  final List<Color> _gradientColors = [
    const Color(0xFF1a1a2e),
    const Color(0xFF16213e),
    const Color(0xFF0f3460),
  ];

  String _normalizeArabic(String input) {
    var s = input.toLowerCase().trim();
    // إزالة التشكيل/الحركات وعلامات القرآن الشائعة حتى لا تؤثر على البحث
    s = s.replaceAll(
      RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'),
      '',
    );
    s = s.replaceAll(RegExp(r'\u0640'), '');
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و');
    s = s.replaceAll(RegExp(r'[^0-9a-z\u0600-\u06FF\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  int _scoreMatch({required String query, required String candidate}) {
    final q = _normalizeArabic(query);
    final c = _normalizeArabic(candidate);
    if (q.isEmpty || c.isEmpty) return 0;
    if (c == q) return 100;
    if (c.startsWith(q)) return 90;
    if (c.contains(q)) return 80;
    final qWords = q.split(' ').where((w) => w.isNotEmpty).toList();
    final cWords = c.split(' ').where((w) => w.isNotEmpty).toList();
    if (qWords.isEmpty || cWords.isEmpty) return 0;
    var hits = 0;
    for (final w in qWords) {
      if (cWords.any((cw) => cw.contains(w) || w.contains(cw))) {
        hits++;
      }
    }
    return hits;
  }

  List<String> _generateQueryVariants(String query, {int max = 25}) {
    final variants = <String>[];
    void add(String s) {
      final v = _normalizeArabic(s);
      if (v.isEmpty) return;
      if (!variants.contains(v)) variants.add(v);
    }

    add(query);
    var q = _normalizeArabic(query);
    if (q.startsWith('ال') && q.length > 2) {
      add(q.substring(2));
    }
    q = q.replaceAll('ال ', '');
    add(q);

    final words = q.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length > 1) {
      for (final w in words) {
        add(w);
        if (w.startsWith('ال') && w.length > 2) add(w.substring(2));
      }
      for (var i = 0; i < words.length - 1; i++) {
        add('${words[i]} ${words[i + 1]}');
      }
    }

    final synonyms = <String, List<String>>{
      'انترنت': ['النت', 'الانترنت', 'نت', 'شبكه', 'شبكة'],
      'واي': ['wifi', 'واي فاي', 'وايفاي'],
      'واي فاي': ['wifi', 'وايفاي', 'واي'],
      'شراء': ['تسوق', 'تسوّق', 'مشتريات'],
      'تسوق': ['شراء', 'مشتريات'],
      'دفع': ['سداد', 'تسديد', 'دفعة'],
      'فاتوره': ['فاتورة', 'حساب'],
      'فاتورة': ['فاتوره', 'حساب'],
      'اتصال': ['مكالمة', 'تليفون', 'هاتف'],
      'مكالمة': ['اتصال', 'تليفون', 'هاتف'],
      'دواء': ['علاج', 'حبة', 'حبوب'],
    };

    for (final w in words) {
      final key = _normalizeArabic(w);
      final alKey = key.startsWith('ال') && key.length > 2
          ? key.substring(2)
          : key;
      for (final k in [key, alKey]) {
        final list = synonyms[k];
        if (list != null) {
          for (final s in list) {
            add(s);
          }
        }
      }
    }

    if (variants.length > max) {
      return variants.take(max).toList();
    }
    return variants;
  }

  Task? _findBestTaskByTitleOrDesc(TaskProvider provider, String query) {
    if (query.trim().isEmpty) return null;
    Task? best;
    var bestScore = 0;
    for (final t in provider.tasks) {
      final s1 = _scoreMatch(query: query, candidate: t.title);
      final s2 = _scoreMatch(query: query, candidate: t.description);
      final score = s1 > s2 ? s1 : s2;
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    if (bestScore >= 2) return best;
    return null;
  }

  void _showSearchResultsSheet({
    required String title,
    required List<Map<String, dynamic>> results,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
                Text(
                  'عدد النتائج: ${results.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Colors.white12, height: 12),
                    itemBuilder: (context, index) {
                      final r = results[index];
                      final rTitle = (r['title'] as String?)?.trim() ?? '';
                      final preview = (r['preview'] as String?)?.trim() ?? '';
                      final id = (r['id'] as String?)?.trim() ?? '';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          rTitle.isEmpty ? '(بدون عنوان)' : rTitle,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (preview.isNotEmpty)
                              Text(
                                preview,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            if (id.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'ID: $id',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoiceHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'تعليمات ونصائح',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'نصائح للاستخدام المثالي:\n'
              '- تكلم بسرعة وبجملة واحدة (مهم) لتقليل انقطاع التعرف على الصوت.\n'
              '- اذكر المطلوب مباشرة: (أضف مهمة/احذف مهمة/ابحث عن ملاحظة...).\n'
              '- عند وجود عناصر متشابهة اذكر كلمة مميزة من العنوان أو جزء من الوصف.\n'
              '- يمكنك قول: (ابحث عن...) أولاً ثم (احذف النتيجة) إذا لم تكن متأكدًا.\n'
              '- عند التراجع استخدم زر (تراجع) أو أغلق الإشعار بزر (X).',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Note? _findBestNoteByTitleOrContent(NoteProvider provider, String query) {
    if (query.trim().isEmpty) return null;
    Note? best;
    var bestScore = 0;
    for (final n in provider.notes) {
      final s1 = _scoreMatch(query: query, candidate: n.title);
      final s2 = _scoreMatch(query: query, candidate: n.content);
      final score = s1 > s2 ? s1 : s2;
      if (score > bestScore) {
        bestScore = score;
        best = n;
      }
    }
    if (bestScore >= 2) return best;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeServices();
  }

  void _initializeServices() async {
    await _sttService.initialize();
    await TtsService.initialize();
    _loadHistory();
  }

  /// تحميل السجل السابق من قاعدة البيانات
  Future<void> _loadHistory() async {
    try {
      final messages = await ChatHistoryService.getRecentMessages(
        limit: 50,
        sessionId: 'voice_chat',
      );

      if (messages.isEmpty) return;

      final List<Map<String, String>> history = [];

      // الرسائل تأتي مرتبة من الأحدث للأقدم
      // نحتاج لتجميعها في أزواج (سؤال + جواب)
      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        final isUser = msg['is_user'] == 1;

        if (!isUser) {
          // هذا رد من المساعد، نبحث عن سؤال المستخدم قبله (في الزمن، يعني بعده في القائمة المعكوسة)
          String question = '';
          String answer = msg['content'] as String;
          String time = msg['timestamp'] as String;

          if (i + 1 < messages.length) {
            final nextMsg = messages[i + 1];
            if (nextMsg['is_user'] == 1) {
              question = nextMsg['content'] as String;
              i++; // تخطي الرسالة التالية لأننا دمجناها
            }
          }

          if (question.isNotEmpty || answer.isNotEmpty) {
            history.insert(0, {
              'question': question,
              'answer': answer,
              'time': time,
            });
          }
        } else {
          // رسالة مستخدم بدون رد (ربما مقطوعة)، نعرضها وحدها
          history.insert(0, {
            'question': msg['content'] as String,
            'answer': '...',
            'time': msg['timestamp'] as String,
          });
        }
      }

      if (mounted) {
        setState(() {
          _conversationHistory.clear();
          _conversationHistory.addAll(history);
        });

        // التمرير للأسفل بعد تحميل البيانات
        Future.delayed(const Duration(milliseconds: 500), _scrollToBottom);
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startListening() async {
    HapticFeedback.mediumImpact();

    // Stop TTS if speaking
    if (TtsService.isSpeaking) {
      await TtsService.stop();
    }

    try {
      // Launch native voice recognition activity
      final String? text = await SystemVoiceService.startVoiceRecognition();

      if (text != null && text.isNotEmpty) {
        setState(() {
          _currentSpeech = text;
          _state = VoiceChatState.processing;
        });

        // Process the text immediately
        _processText(text);
      } else {
        // User canceled or no text
        setState(() => _state = VoiceChatState.idle);
      }
    } catch (e) {
      debugPrint('System Voice Error: $e');
      if (mounted) {
        AppSnackBar.error(context, 'حدث خطأ في التعرف على الصوت');
      }
      setState(() => _state = VoiceChatState.idle);
    }
  }

  // Remove old logic that is no longer needed
  // _listenWithRestart, _startSimpleListening, etc. can be removed.
  // Instead of _stopListeningAndProcess, we just have _processText

  // لم نعد نحتاج مؤقت الصمت - يتحكم المستخدم بوقت الكلام

  // Process the text returned from system voice intent
  Future<void> _processText(String fullText) async {
    // _stopListeningTimer?.cancel(); // Not needed
    // await _sttService.stop(); // Not needed
    _pulseController.stop();
    _pulseController.reset();

    if (!mounted) return;

    final fullText = _currentSpeech.trim();

    // إذا لم يسمع شيئاً
    if (fullText.isEmpty) {
      setState(() {
        _state = VoiceChatState.idle;
      });
      return;
    }

    setState(() {
      _state = VoiceChatState.processing;
    });

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    try {
      // إرسال النص مباشرة إلى Gemini (لا حاجة لملفات صوت)
      final response = await GeminiService.sendMessage(
        fullText, // النص المسموع الكامل
        // لا نرسل audioBytes لأننا بالفعل حولناه لنص
        sessionId: 'voice_chat',
        onAddTask: (args) async {
          try {
            final title = args['title'] as String;
            final description = args['description'] as String? ?? '';
            final priorityStr = args['priority'] as String? ?? 'medium';
            final dueDateStr = args['dueDate'] as String?;
            final hasReminder = args['hasReminder'] as bool? ?? false;
            final reminderTimeStr = args['reminderTime'] as String?;
            final repeatType = args['repeatType'] as String?;
            final repeatDaysRaw = args['repeatDays'];

            List<int>? repeatDays;
            if (repeatDaysRaw is List) {
              repeatDays = repeatDaysRaw
                  .map((e) => e is int ? e : int.tryParse(e.toString()))
                  .whereType<int>()
                  .toList();
            }

            TaskPriority priority = TaskPriority.medium;
            if (priorityStr.toLowerCase().contains('high')) {
              priority = TaskPriority.high;
            } else if (priorityStr.toLowerCase().contains('low')) {
              priority = TaskPriority.low;
            } else if (priorityStr.toLowerCase().contains('critical')) {
              priority = TaskPriority.critical;
            }

            DateTime? dueDate;
            if (dueDateStr != null) {
              final parsed = DateTime.tryParse(dueDateStr);
              if (parsed != null) {
                // إذا كان ISO مع Z/offset فسيكون UTC -> حوّله للمحلي
                dueDate = parsed.isUtc ? parsed.toLocal() : parsed;
              }
            }

            DateTime? reminderTime;
            if (reminderTimeStr != null) {
              final parsed = DateTime.tryParse(reminderTimeStr);
              if (parsed != null) {
                reminderTime = parsed.isUtc ? parsed.toLocal() : parsed;
              }
            }

            // إذا hasReminder true ولم يرسل reminderTime صريح، استخدم dueDate
            if (hasReminder == true && reminderTime == null) {
              reminderTime = dueDate;
            }

            final newTask = Task(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              description: description,
              priority: priority,
              dueDate: dueDate,
              reminderTime: hasReminder ? reminderTime : null,
              repeatType: repeatType ?? 'none',
              repeatDays: repeatDays ?? const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            debugPrint('Adding task from Voice AI: $title');
            await taskProvider.addTask(newTask);
            _lastTaskId = newTask.id;

            if (mounted) {
              AppSnackBar.showUndo(
                context,
                message: 'تمت إضافة المهمة: "${newTask.title}"',
                type: AppSnackBarType.success,
                onUndo: () async {
                  await taskProvider.deleteTask(newTask.id);
                  if (mounted) {
                    AppSnackBar.info(context, 'تم التراجع عن إضافة المهمة');
                  }
                },
              );
            }

            final next = newTask.nextOccurrence;
            if (next != null && next.isAfter(DateTime.now())) {
              await AlarmService().scheduleAlarm(
                scheduledTime: next,
                title: newTask.title,
                body: newTask.description,
                taskId: newTask.id,
                repeatType: newTask.repeatType,
                repeatDays: newTask.repeatDays,
              );
            }

            return {'success': true, 'message': 'Task added successfully'};
          } catch (e) {
            return {'success': false, 'message': 'Failed to add task: $e'};
          }
        },
        onAddNote: (args) async {
          try {
            final title = args['title'] as String;
            final content = args['content'] as String? ?? '';

            final newNote = noteProvider.createNewNote(
              title: title,
              content: content,
            );

            await noteProvider.addNote(newNote);
            _lastNoteId = newNote.id;

            if (mounted) {
              AppSnackBar.showUndo(
                context,
                message: 'تمت إضافة الملاحظة: "${newNote.title}"',
                type: AppSnackBarType.success,
                onUndo: () async {
                  await noteProvider.deleteNote(newNote.id);
                  if (mounted) {
                    AppSnackBar.info(context, 'تم التراجع عن إضافة الملاحظة');
                  }
                },
              );
            }

            return {'success': true, 'message': 'Note added successfully'};
          } catch (e) {
            return {'success': false, 'message': 'Failed to add note: $e'};
          }
        },
        onUpdateTask: (args) async {
          try {
            final taskId = args['taskId'] as String?;
            final matchTitle = args['matchTitle'] as String?;

            final title = args['title'] as String?;
            final description = args['description'] as String?;
            final priorityStr = args['priority'] as String?;
            final dueDateStr = args['dueDate'] as String?;
            final reminderTimeStr = args['reminderTime'] as String?;
            final repeatType = args['repeatType'] as String?;
            final repeatDaysRaw = args['repeatDays'];
            final isCompleted = args['isCompleted'] as bool?;

            List<int>? repeatDays;
            if (repeatDaysRaw is List) {
              repeatDays = repeatDaysRaw
                  .map((e) => e is int ? e : int.tryParse(e.toString()))
                  .whereType<int>()
                  .toList();
            }

            final hasReminder = args['hasReminder'] as bool?;
            final clearDueDate = args['clearDueDate'] as bool? ?? false;
            final clearReminderTime =
                args['clearReminderTime'] as bool? ?? false;

            Task? target;
            if (taskId != null) {
              target = taskProvider.tasks
                  .where((t) => t.id == taskId)
                  .cast<Task?>()
                  .firstWhere((t) => t != null, orElse: () => null);
            }

            // fallback: آخر مهمة تم التعامل معها
            if (target == null && _lastTaskId != null) {
              target = taskProvider.tasks
                  .where((t) => t.id == _lastTaskId)
                  .cast<Task?>()
                  .firstWhere((t) => t != null, orElse: () => null);
            }

            if (target == null && matchTitle != null && matchTitle.isNotEmpty) {
              target = _findBestTaskByTitleOrDesc(taskProvider, matchTitle);
            }

            if (target == null) {
              return {
                'success': false,
                'message': matchTitle != null && matchTitle.isNotEmpty
                    ? 'لم أجد مهمة مطابقة لـ "$matchTitle"'
                    : 'لم يتم تحديد مهمة للتعديل',
              };
            }

            final noChangeRequested =
                title == null &&
                description == null &&
                priorityStr == null &&
                dueDateStr == null &&
                reminderTimeStr == null &&
                repeatType == null &&
                isCompleted == null &&
                hasReminder == null &&
                clearDueDate == false &&
                clearReminderTime == false;
            if (noChangeRequested) {
              return {
                'success': false,
                'message': 'لم يتم التعديل لأن الطلب لا يحتوي على تغييرات',
              };
            }

            final previousTask = target;

            TaskPriority? newPriority;
            if (priorityStr != null) {
              final p = priorityStr.toLowerCase();
              if (p.contains('high')) {
                newPriority = TaskPriority.high;
              } else if (p.contains('low')) {
                newPriority = TaskPriority.low;
              } else if (p.contains('critical')) {
                newPriority = TaskPriority.critical;
              } else if (p.contains('medium')) {
                newPriority = TaskPriority.medium;
              }
            }

            DateTime? dueDate;
            if (dueDateStr != null) {
              final parsed = DateTime.tryParse(dueDateStr);
              if (parsed != null) {
                dueDate = parsed.isUtc ? parsed.toLocal() : parsed;
              }
            }

            DateTime? reminderTime;
            if (reminderTimeStr != null) {
              final parsed = DateTime.tryParse(reminderTimeStr);
              if (parsed != null) {
                reminderTime = parsed.isUtc ? parsed.toLocal() : parsed;
              }
            }

            // إذا hasReminder true ولم يرسل reminderTime صريح، استخدم dueDate
            if (hasReminder == true && reminderTime == null) {
              reminderTime = dueDate;
            }

            // حالة الإكمال (منجزة/غير منجزة)
            final now = DateTime.now();
            final newIsCompleted = isCompleted;
            final completedAt = newIsCompleted == null
                ? null
                : (newIsCompleted ? now : null);

            final updatedTask = target.copyWith(
              title: title,
              description: description,
              priority: newPriority,
              dueDate: dueDate,
              clearDueDate: clearDueDate,
              reminderTime: reminderTime,
              clearReminderTime: clearReminderTime,
              repeatType: repeatType,
              repeatDays: repeatDays,
              isCompleted: newIsCompleted,
              completedAt: completedAt,
            );

            await taskProvider.updateTask(updatedTask);
            _lastTaskId = updatedTask.id;

            if (mounted) {
              AppSnackBar.showUndo(
                context,
                message: 'تم تحديث المهمة: "${updatedTask.title}"',
                type: AppSnackBarType.success,
                onUndo: () async {
                  await taskProvider.updateTask(previousTask);
                  await NotificationService().cancelTaskNotifications(
                    previousTask.id,
                  );
                  AlarmService().cancelScheduledAlarm();
                  final prevNext = previousTask.nextOccurrence;
                  if (prevNext != null &&
                      prevNext.isAfter(DateTime.now()) &&
                      !previousTask.isCompleted) {
                    await AlarmService().scheduleAlarm(
                      scheduledTime: prevNext,
                      title: previousTask.title,
                      body: previousTask.description,
                      taskId: previousTask.id,
                      repeatType: previousTask.repeatType,
                      repeatDays: previousTask.repeatDays,
                    );
                  }
                  if (mounted) {
                    AppSnackBar.info(context, 'تم التراجع عن التحديث');
                  }
                },
              );
            }

            // إعادة جدولة/إلغاء التذكير
            await NotificationService().cancelTaskNotifications(updatedTask.id);
            AlarmService().cancelScheduledAlarm();
            final next = updatedTask.nextOccurrence;
            if (next != null &&
                next.isAfter(DateTime.now()) &&
                !updatedTask.isCompleted) {
              await AlarmService().scheduleAlarm(
                scheduledTime: next,
                title: updatedTask.title,
                body: updatedTask.description,
                taskId: updatedTask.id,
                repeatType: updatedTask.repeatType,
                repeatDays: updatedTask.repeatDays,
              );
            }

            return {'success': true, 'message': 'Task updated successfully'};
          } catch (e) {
            return {'success': false, 'message': 'Failed to update task: $e'};
          }
        },
        onUpdateNote: (args) async {
          try {
            final noteId = args['noteId'] as String?;
            final matchTitle = args['matchTitle'] as String?;

            final title = args['title'] as String?;
            final content = args['content'] as String?;

            Note? target;
            if (noteId != null) {
              target = noteProvider.notes
                  .where((n) => n.id == noteId)
                  .cast<Note?>()
                  .firstWhere((n) => n != null, orElse: () => null);
            }

            // fallback: آخر ملاحظة تم التعامل معها
            if (target == null && _lastNoteId != null) {
              target = noteProvider.notes
                  .where((n) => n.id == _lastNoteId)
                  .cast<Note?>()
                  .firstWhere((n) => n != null, orElse: () => null);
            }

            if (target == null && matchTitle != null && matchTitle.isNotEmpty) {
              target = _findBestNoteByTitleOrContent(noteProvider, matchTitle);
            }

            // إذا لم يحدد المستخدم عنوان/معرف، اختر آخر ملاحظة (الأحدث تحديثاً)
            if (target == null && noteProvider.notes.isNotEmpty) {
              final sorted = [...noteProvider.notes];
              sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              target = sorted.first;
            }

            if (target == null) {
              return {
                'success': false,
                'message': matchTitle != null && matchTitle.isNotEmpty
                    ? 'لم أجد ملاحظة مطابقة لـ "$matchTitle"'
                    : 'لم يتم تحديد ملاحظة للتعديل',
              };
            }

            final noChangeRequested = title == null && content == null;
            if (noChangeRequested) {
              return {
                'success': false,
                'message': 'لم يتم التعديل لأن الطلب لا يحتوي على تغييرات',
              };
            }

            final previousNote = target;

            final updatedNote = target.copyWith(
              title: title,
              content: content,
              updatedAt: DateTime.now(),
            );

            await noteProvider.updateNote(updatedNote);
            _lastNoteId = updatedNote.id;

            if (mounted) {
              AppSnackBar.showUndo(
                context,
                message: 'تم تحديث الملاحظة: "${updatedNote.title}"',
                type: AppSnackBarType.success,
                onUndo: () async {
                  await noteProvider.updateNote(previousNote);
                  if (mounted) {
                    AppSnackBar.info(context, 'تم التراجع عن التحديث');
                  }
                },
              );
            }
            return {'success': true, 'message': 'Note updated successfully'};
          } catch (e) {
            return {'success': false, 'message': 'Failed to update note: $e'};
          }
        },
        onSearchNotes: (args) async {
          try {
            final query = (args['query'] as String? ?? '').trim();
            if (query.isEmpty) {
              return {'success': false, 'message': 'Missing query'};
            }

            final variants = _generateQueryVariants(query, max: 25);
            final scored = <String, Map<String, Object?>>{};
            final scores = <String, int>{};

            for (final v in variants) {
              for (final n in noteProvider.notes) {
                final s1 = _scoreMatch(query: v, candidate: n.title);
                final s2 = _scoreMatch(query: v, candidate: n.content);
                final score = s1 > s2 ? s1 : s2;
                if (score <= 0) continue;
                final prev = scores[n.id] ?? 0;
                if (score > prev) {
                  scores[n.id] = score;
                  final preview = n.content.trim();
                  final shortPreview = preview.length > 60
                      ? preview.substring(0, 60)
                      : preview;
                  scored[n.id] = {
                    'id': n.id,
                    'title': n.title,
                    'preview': shortPreview,
                  };
                }
              }
            }

            final ids = scored.keys.toList();
            ids.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
            final results = ids.take(10).map((id) => scored[id]!).toList();

            if (results.isNotEmpty) {
              _lastNoteId = results.first['id'] as String;
            }

            if (mounted) {
              _showSearchResultsSheet(
                title: 'نتائج البحث في الملاحظات: "$query"',
                results: results,
              );
            }

            return {
              'success': true,
              'count': results.length,
              'results': results,
            };
          } catch (e) {
            return {'success': false, 'message': 'Failed to search notes: $e'};
          }
        },
        onSearchTasks: (args) async {
          try {
            final query = (args['query'] as String? ?? '').trim();
            if (query.isEmpty) {
              return {'success': false, 'message': 'Missing query'};
            }

            final variants = _generateQueryVariants(query, max: 25);
            final scored = <String, Map<String, Object?>>{};
            final scores = <String, int>{};

            for (final v in variants) {
              for (final t in taskProvider.tasks) {
                final s1 = _scoreMatch(query: v, candidate: t.title);
                final s2 = _scoreMatch(query: v, candidate: t.description);
                final score = s1 > s2 ? s1 : s2;
                if (score <= 0) continue;
                final prev = scores[t.id] ?? 0;
                if (score > prev) {
                  scores[t.id] = score;
                  final preview = t.description.trim();
                  final shortPreview = preview.length > 60
                      ? preview.substring(0, 60)
                      : preview;
                  scored[t.id] = {
                    'id': t.id,
                    'title': t.title,
                    'preview': shortPreview,
                    'isCompleted': t.isCompleted,
                    'dueDate': t.dueDate?.toIso8601String(),
                    'reminderTime': t.reminderTime?.toIso8601String(),
                  };
                }
              }
            }

            final ids = scored.keys.toList();
            ids.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
            final results = ids.take(10).map((id) => scored[id]!).toList();

            if (results.isNotEmpty) {
              _lastTaskId = results.first['id'] as String;
            }

            if (mounted) {
              _showSearchResultsSheet(
                title: 'نتائج البحث في المهام: "$query"',
                results: results,
              );
            }

            return {
              'success': true,
              'count': results.length,
              'results': results,
            };
          } catch (e) {
            return {'success': false, 'message': 'Failed to search tasks: $e'};
          }
        },
        onDeleteNote: (args) async {
          try {
            final noteId = args['noteId'] as String?;
            final matchTitle = args['matchTitle'] as String?;

            String? targetId = noteId;
            if (targetId == null && _lastNoteId != null) {
              targetId = _lastNoteId;
            }

            if (targetId == null &&
                matchTitle != null &&
                matchTitle.isNotEmpty) {
              final best = _findBestNoteByTitleOrContent(
                noteProvider,
                matchTitle,
              );
              targetId = best?.id;
            }

            if (targetId == null && noteProvider.notes.isNotEmpty) {
              final sorted = [...noteProvider.notes];
              sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              targetId = sorted.first.id;
            }

            if (targetId == null) {
              return {
                'success': false,
                'message': matchTitle != null && matchTitle.isNotEmpty
                    ? 'لم أجد ملاحظة مطابقة لـ "$matchTitle"'
                    : 'لم يتم تحديد ملاحظة للحذف',
              };
            }

            final noteTitle = noteProvider.notes
                .where((n) => n.id == targetId)
                .map((n) => n.title)
                .cast<String?>()
                .firstWhere((t) => t != null, orElse: () => null);

            await noteProvider.deleteNote(targetId);
            _lastNoteId = targetId;

            if (mounted) {
              AppSnackBar.showUndo(
                context,
                message: noteTitle != null
                    ? 'تم حذف الملاحظة: "$noteTitle"'
                    : 'تم حذف الملاحظة',
                type: AppSnackBarType.warning,
                onUndo: () async {
                  await noteProvider.restoreNote(targetId!);
                  if (mounted) {
                    AppSnackBar.info(context, 'تم التراجع عن الحذف');
                  }
                },
              );
            }
            return {'success': true, 'message': 'Note deleted successfully'};
          } catch (e) {
            return {'success': false, 'message': 'Failed to delete note: $e'};
          }
        },
        onDeleteTask: (args) async {
          try {
            final taskId = args['taskId'] as String?;
            final matchTitle = args['matchTitle'] as String?;

            String? targetId = taskId;
            if (targetId == null && _lastTaskId != null) {
              targetId = _lastTaskId;
            }

            if (targetId == null &&
                matchTitle != null &&
                matchTitle.isNotEmpty) {
              final best = _findBestTaskByTitleOrDesc(taskProvider, matchTitle);
              targetId = best?.id;
            }

            if (targetId == null) {
              return {
                'success': false,
                'message': matchTitle != null && matchTitle.isNotEmpty
                    ? 'لم أجد مهمة مطابقة لـ "$matchTitle"'
                    : 'لم يتم تحديد مهمة للحذف',
              };
            }

            final taskTitle = taskProvider.tasks
                .where((t) => t.id == targetId)
                .map((t) => t.title)
                .cast<String?>()
                .firstWhere((t) => t != null, orElse: () => null);

            await taskProvider.deleteTask(targetId);
            _lastTaskId = targetId;

            if (mounted) {
              AppSnackBar.showUndo(
                context,
                message: taskTitle != null
                    ? 'تم حذف المهمة: "$taskTitle"'
                    : 'تم حذف المهمة',
                type: AppSnackBarType.warning,
                onUndo: () async {
                  await taskProvider.restoreTask(targetId!);
                  if (mounted) {
                    AppSnackBar.info(context, 'تم التراجع عن الحذف');
                  }
                },
              );
            }
            return {'success': true, 'message': 'Task deleted successfully'};
          } catch (e) {
            return {'success': false, 'message': 'Failed to delete task: $e'};
          }
        },
        onSetAlarm: (args) async {
          final minutes = args['minutes'] as int?;
          final title = args['title'] as String? ?? 'تذكير';
          final timeStr = args['time'] as String?;
          final repeatType = args['repeatType'] as String? ?? 'none';

          DateTime? scheduledTime;
          if (timeStr != null && timeStr.trim().isNotEmpty) {
            final parts = timeStr.trim().split(':');
            if (parts.length >= 2) {
              final h = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              if (h != null && m != null) {
                final now = DateTime.now();
                var candidate = DateTime(now.year, now.month, now.day, h, m);
                if (!candidate.isAfter(now)) {
                  candidate = candidate.add(const Duration(days: 1));
                }
                scheduledTime = candidate;
              }
            }
          } else if (minutes != null) {
            scheduledTime = DateTime.now().add(Duration(minutes: minutes));
          }

          if (scheduledTime != null) {
            debugPrint('Scheduling Voice alarm & adding task from AI: $title');
            final newTask = Task(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              description: 'تذكير صوتي من المساعد',
              priority: TaskPriority.medium,
              dueDate: scheduledTime,
              reminderTime: scheduledTime,
              repeatType: repeatType,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await taskProvider.addTask(newTask);

            await AlarmService().scheduleAlarm(
              scheduledTime: scheduledTime,
              title: title,
              body: newTask.description,
              taskId: newTask.id,
              repeatType: repeatType,
            );
          }
        },
        onSendNotification: (args) async {
          await NotificationService().showAiNotification(
            title: args['title'] as String? ?? 'تنبيه',
            body: args['body'] as String? ?? '',
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _state = VoiceChatState.speaking;
      });

      // حفظ الرد في سجل المحادثات
      await ChatHistoryService.saveMessage(
        content: _currentSpeech,
        isUser: true,
        sessionId: 'voice_chat',
      );
      await ChatHistoryService.saveMessage(
        content: response,
        isUser: false,
        sessionId: 'voice_chat',
      );

      // حفظ في السجل المحلي للعرض
      _conversationHistory.add({
        'question': fullText,
        'answer': response,
        'time': DateTime.now().toString(),
      });

      _scrollToBottom(); // تمرير السجل للأسفل

      // نطق الرد
      await TtsService.speak(response);

      if (mounted) {
        setState(() => _state = VoiceChatState.idle);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = VoiceChatState.idle;
      });
    }
  }

  /// عرض نافذة تأكيد حذف السجل
  void _showDeleteHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('حذف السجل', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'هل تريد حذف جميع المحادثات الصوتية (${_conversationHistory.length} محادثة)؟\n\nلا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllHistory();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// حذف جميع المحادثات
  Future<void> _deleteAllHistory() async {
    // حذف السجل المحلي وتحديث الواجهة فوراً
    setState(() {
      _conversationHistory.clear();
      _currentSpeech = '';
    });

    // حذف من قاعدة البيانات
    await ChatHistoryService.clearHistory();

    if (mounted) {
      AppSnackBar.success(context, 'تم حذف سجل المحادثات');
    }
  }

  void _stopSpeaking() {
    TtsService.stop();
    setState(() => _state = VoiceChatState.idle);
  }

  void _toggleTtsEnabled() async {
    await TtsService.toggleEnabled();
    if (!mounted) return;
    setState(() {});
    AppSnackBar.info(
      context,
      TtsService.isEnabled ? 'تم تفعيل التحدث' : 'تم تعطيل التحدث',
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _historyScrollController.dispose();
    _stopListeningTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_historyScrollController.hasClients) {
        _historyScrollController.animateTo(
          _historyScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _gradientColors,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(),

                    // سجل المحادثات (يأخذ المساحة المتاحة)
                    Expanded(
                      child: _conversationHistory.isEmpty
                          ? _buildEmptyState()
                          : _buildHistoryList(),
                    ),

                    // منطقة التفاعل (الزر وحالة الاستماع)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        border: const Border(
                          top: BorderSide(color: Colors.white10),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_state == VoiceChatState.listening ||
                              _currentSpeech.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 30),
                              child: Text(
                                _currentSpeech.trim(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          // الزر والموجات
                          _buildMainButton(),

                          if (_state == VoiceChatState.listening ||
                              _state == VoiceChatState.processing ||
                              _state == VoiceChatState.speaking) ...[
                            const SizedBox(height: 20),
                            _buildStatusText(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // شاشة قيد التطوير تظهر فوق كل شيء
            if (_showDevOverlay) _buildDevOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildDevOverlay() {
    return Container(
      color: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie Animation
          SizedBox(
            width: 250,
            height: 250,
            child: Lottie.asset(
              'assets/animations/Robot-Bot 3D.lottie',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if lottie file issue
                return const Icon(
                  Icons.smart_toy_rounded,
                  size: 100,
                  color: Colors.blueAccent,
                );
              },
            ),
          ),
          const SizedBox(height: 30),

          // Title
          const Text(
            'المساعد الذكي',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 10),

          // Subtitle (Under Development tag)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orangeAccent.withValues(alpha: 0.5),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  color: Colors.orangeAccent,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'قيد التطوير',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Start Button
          FilledButton.icon(
            onPressed: () {
              setState(() => _showDevOverlay = false);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('بدء التجربة'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 10,
              shadowColor: Colors.blueAccent.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none_outlined,
            size: 100,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد محادثات بعد',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      controller: _historyScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _conversationHistory.length,
      itemBuilder: (context, index) {
        final item = _conversationHistory[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // سؤال المستخدم
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(left: 40),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    item['question'] ?? '',
                    textDirection: TextUtils.getTextDirection(
                      item['question'] ?? '',
                    ),
                    textAlign: TextUtils.getTextAlign(item['question'] ?? ''),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // رد المساعد
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(right: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    item['answer'] ?? '',
                    textDirection: TextUtils.getTextDirection(
                      item['answer'] ?? '',
                    ),
                    textAlign: TextUtils.getTextAlign(item['answer'] ?? ''),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'المساعد الصوتي',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: TtsService.isSpeaking ? _stopSpeaking : null,
            icon: Icon(
              Icons.stop,
              color: TtsService.isSpeaking ? Colors.white : Colors.white24,
            ),
            tooltip: 'إيقاف التحدث',
          ),
          IconButton(
            onPressed: _toggleTtsEnabled,
            icon: Icon(
              TtsService.isEnabled ? Icons.volume_up : Icons.volume_off,
              color: TtsService.isEnabled ? Colors.white : Colors.orangeAccent,
            ),
            tooltip: TtsService.isEnabled ? 'تعطيل التحدث' : 'تفعيل التحدث',
          ),
          IconButton(
            onPressed: _showVoiceHelpDialog,
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            tooltip: 'تعليمات ونصائح',
          ),
          // زر حذف سجل المحادثات
          if (_conversationHistory.isNotEmpty)
            IconButton(
              onPressed: _showDeleteHistoryDialog,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'حذف سجل المحادثات',
            ),
        ],
      ),
    );
  }

  Widget _buildMainButton() {
    final isListening = _state == VoiceChatState.listening;
    final isProcessing = _state == VoiceChatState.processing;
    final isSpeaking = _state == VoiceChatState.speaking;

    return GestureDetector(
      onTap: () {
        if (isSpeaking) {
          _stopSpeaking();
        } else if (_state == VoiceChatState.idle) {
          _startListening();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الموجات الدائرية خلف الزر
          if (isListening || isSpeaking)
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(220, 220),
                  painter: CircularWavePainter(
                    animation: _waveController.value,
                    color: isListening ? Colors.red : Colors.blue,
                  ),
                );
              },
            ),

          // الزر الرئيسي
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isListening ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isListening
                          ? [Colors.redAccent, Colors.red.shade900]
                          : isProcessing
                          ? [Colors.orangeAccent, Colors.orange.shade900]
                          : isSpeaking
                          ? [Colors.blueAccent, Colors.blue.shade900]
                          : [const Color(0xFF2193b0), const Color(0xFF6dd5ed)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isListening
                                    ? Colors.red
                                    : isProcessing
                                    ? Colors.orange
                                    : isSpeaking
                                    ? Colors.blue
                                    : const Color(0xFF2193b0))
                                .withValues(alpha: 0.5),
                        blurRadius: isListening || isSpeaking ? 40 : 20,
                        spreadRadius: isListening || isSpeaking ? 10 : 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: isProcessing
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            isListening
                                ? Icons.mic
                                : isSpeaking
                                ? Icons.stop
                                : Icons.mic_none,
                            size: 40,
                            color: Colors.white,
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    String text;
    Color color;

    switch (_state) {
      case VoiceChatState.idle:
        return const SizedBox.shrink();
      case VoiceChatState.listening:
        text = 'اضغط مرة أخرى للإرسال';
        color = Colors.white70;
        break;
      case VoiceChatState.processing:
        text = 'أفكر في الرد...';
        color = Colors.orange.shade300;
        break;
      case VoiceChatState.speaking:
        text = 'اضغط للإيقاف';
        color = Colors.blue.shade300;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          text,
          key: ValueKey(text),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// حالات شاشة المحادثة الصوتية
enum VoiceChatState { idle, listening, processing, speaking }

/// رسام الموجة الصوتية
class WavePainter extends CustomPainter {
  final double animation;
  final Color color;
  final double amplitude; // 0.0 - 1.0

  WavePainter({
    required this.animation,
    required this.color,
    this.amplitude = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // ارتفاع الموجة يتأثر بمستوى الصوت
    final baseHeight = 10.0;
    final waveHeight =
        baseHeight + (amplitude * 30.0); // 10 - 40 بناءً على amplitude
    final waveCount = 3;

    path.moveTo(0, size.height / 2);

    for (double i = 0; i <= size.width; i++) {
      final y =
          sin((i / size.width * waveCount * pi * 2) + (animation * pi * 2)) *
              waveHeight +
          size.height / 2;
      path.lineTo(i, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      animation != oldDelegate.animation ||
      color != oldDelegate.color ||
      amplitude != oldDelegate.amplitude;
}

/// رسام الموجات الدائرية المتفاعلة
class CircularWavePainter extends CustomPainter {
  final double animation;
  final Color color;

  CircularWavePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final waveValue = (animation + (i / 3)) % 1.0;
      final radius = (size.width / 2) * waveValue;
      final opacity = (1.0 - waveValue).clamp(0.0, 1.0);

      paint.color = color.withValues(alpha: opacity * 0.5);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(CircularWavePainter oldDelegate) =>
      animation != oldDelegate.animation || color != oldDelegate.color;
}
