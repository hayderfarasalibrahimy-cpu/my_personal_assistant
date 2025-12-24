import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/chat_history_service.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';
import '../widgets/assistant_avatar.dart';
import '../providers/task_provider.dart';
import '../providers/note_provider.dart';
import '../models/task.dart';
import '../models/note.dart';
import 'package:provider/provider.dart';
import '../utils/app_snackbar.dart';
import '../utils/text_utils.dart';

/// شاشة المحادثة مع Gemini AI
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  Uint8List? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  String? _lastTaskId;
  String? _lastNoteId;

  void _showSearchResultsSheet({
    required String title,
    required List<Map<String, dynamic>> results,
  }) {
    showModalBottomSheet(
      context: context,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
                Text('عدد النتائج: ${results.length}'),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final r = results[index];
                      final rTitle = (r['title'] as String?)?.trim() ?? '';
                      final preview = (r['preview'] as String?)?.trim() ?? '';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(rTitle.isEmpty ? '(بدون عنوان)' : rTitle),
                        subtitle: preview.isEmpty ? null : Text(preview),
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

  String _normalizeArabic(String input) {
    var s = input.toLowerCase().trim();
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

  String? _findBestTaskId(TaskProvider provider, String query) {
    return _findBestTaskByTitleOrDesc(provider, query)?.id;
  }

  String? _findBestNoteId(NoteProvider provider, String query) {
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
    if (bestScore >= 2) return best?.id;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedMessages();
    TtsService.initialize();
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

  /// تحميل الرسائل المحفوظة من قاعدة البيانات
  Future<void> _loadSavedMessages() async {
    try {
      final savedMessages = await ChatHistoryService.getRecentMessages(
        limit: 50,
        sessionId: 'main_chat',
      );

      if (savedMessages.isNotEmpty && mounted) {
        // ترتيب الرسائل من الأقدم للأحدث
        final sorted = savedMessages.reversed.toList();

        setState(() {
          for (final msg in sorted) {
            _messages.add(
              ChatMessage(
                text: msg['content'] as String,
                isUser: msg['is_user'] == 1,
              ),
            );
          }
        });
        _scrollToBottom();
      } else if (mounted) {
        // إذا لم توجد رسائل محفوظة، أضف رسالة ترحيب شخصية
        final greeting = await GeminiService.getPersonalizedGreeting();
        _addMessage(ChatMessage(text: greeting, isUser: false));
      }
    } catch (e) {
      // في حالة الخطأ، أضف رسالة ترحيب بسيطة
      if (mounted) {
        _addMessage(
          ChatMessage(
            text:
                '${GeminiService.getSmartGreeting()}\nأنا المساعد الذكي، كيف يمكنني مساعدتك؟',
            isUser: false,
          ),
        );
      }
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final image = _selectedImage;

    if (text.isEmpty && image == null) {
      return; // Allow sending image only or text only (if handled) but usually need prompt with image
    }

    _addMessage(ChatMessage(text: text, isUser: true, image: image));
    _controller.clear();
    setState(() => _selectedImage = null);

    setState(() => _isLoading = true);

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    String response;
    try {
      response = await GeminiService.sendMessage(
        text,
        image: image,
        sessionId: 'main_chat',
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

            debugPrint('Adding task from AI: $title');
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
                    AppSnackBar.info(context, 'تم التراجع عن الإضافة');
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
                    AppSnackBar.info(context, 'تم التراجع عن الإضافة');
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
                  final next = previousTask.nextOccurrence;
                  if (next != null &&
                      next.isAfter(DateTime.now()) &&
                      !previousTask.isCompleted) {
                    await AlarmService().scheduleAlarm(
                      scheduledTime: next,
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
              targetId = _findBestNoteId(noteProvider, matchTitle);
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
              targetId = _findBestTaskId(taskProvider, matchTitle);
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
            debugPrint('Scheduling alarm & adding task from AI: $title');

            // إضافة المهمة أولاً
            final newTask = Task(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              description: 'تذكير تلقائي من المساعد',
              priority: TaskPriority.medium,
              dueDate: scheduledTime,
              reminderTime: scheduledTime,
              repeatType: repeatType,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await taskProvider.addTask(newTask);
            _lastTaskId = newTask.id;

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
    } catch (e) {
      response = e.toString();
      if (mounted) {
        AppSnackBar.error(context, response);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _addMessage(ChatMessage(text: response, isUser: false));
    }

    // حفظ المحادثة في السجل
    await ChatHistoryService.saveMessage(
      content: text.isNotEmpty ? text : '[صورة]',
      isUser: true,
      sessionId: 'main_chat',
    );
    await ChatHistoryService.saveMessage(
      content: response,
      isUser: false,
      sessionId: 'main_chat',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحادثة مع المساعد'),
          actions: [
            IconButton(
              onPressed: TtsService.isSpeaking ? TtsService.stop : null,
              icon: Icon(
                Icons.stop,
                color: TtsService.isSpeaking
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              tooltip: 'إيقاف التحدث',
            ),
            IconButton(
              onPressed: _toggleTtsEnabled,
              icon: Icon(
                TtsService.isEnabled ? Icons.volume_up : Icons.volume_off,
              ),
              tooltip: TtsService.isEnabled ? 'تعطيل التحدث' : 'تفعيل التحدث',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'مسح المحادثة',
              onPressed: () async {
                await GeminiService.clearHistory();
                if (mounted) {
                  setState(() {
                    _messages.clear();
                    _addMessage(
                      ChatMessage(
                        text:
                            '${GeminiService.getSmartGreeting()}\nأنا المساعد الذكي، كيف يمكنني مساعدتك؟',
                        isUser: false,
                      ),
                    );
                  });
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'المساعد يكتب...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null)
            Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_selectedImage!),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _removeImage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                tooltip: 'إرفاق صورة',
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textDirection: TextUtils.getTextDirection(_controller.text),
                  textAlign: TextUtils.getTextAlign(_controller.text),
                  onSubmitted: (_) => _sendMessage(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed:
                    (_controller.text.isNotEmpty || _selectedImage != null)
                    ? _sendMessage
                    : null,
                mini: true,
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    AppSnackBar.info(context, 'تم نسخ النص ✓');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            const ChatAvatar(size: 36),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.image != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 200,
                              maxWidth: 200,
                            ),
                            child: Image.memory(
                              message.image!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    if (message.text.isNotEmpty)
                      SelectionArea(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: TextSelectionThemeData(
                              selectionColor: message.isUser
                                  ? Colors.amber.withValues(alpha: 0.5)
                                  : Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                              selectionHandleColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ),
                          child: Text(
                            message.text,
                            textDirection: TextUtils.getTextDirection(
                              message.text,
                            ),
                            textAlign: TextUtils.getTextAlign(message.text),
                            style: TextStyle(
                              color: message.isUser
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy,
                          size: 11,
                          color:
                              (message.isUser
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface)
                                  .withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'اضغط مطولاً للنسخ',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                (message.isUser
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface)
                                    .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Icons.person,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Uint8List? image;

  ChatMessage({required this.text, required this.isUser, this.image})
    : timestamp = DateTime.now();
}
