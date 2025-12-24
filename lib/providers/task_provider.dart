import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_service.dart';

class TaskProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Task> _tasks = [];
  List<Task> _hiddenTasks = [];
  List<Task> _deletedTasks = [];
  List<Subtask> _subtasks = [];
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  List<Task> get hiddenTasks => _hiddenTasks;
  List<Task> get deletedTasks => _deletedTasks;
  List<Subtask> get subtasks => _subtasks;
  bool get isLoading => _isLoading;

  // ترتيب المهام: معلقة (غير كلية) - معلقة (كلية) - مكتملة
  List<Task> get pendingTasks {
    final pending = _tasks.where((t) => !t.isCompleted).toList();
    pending.sort((a, b) {
      // مهام "كلية" في النهاية
      final aIsCollege = a.category == 'كلية';
      final bIsCollege = b.category == 'كلية';

      if (aIsCollege && !bIsCollege) return 1;
      if (!aIsCollege && bIsCollege) return -1;

      // نفس التصنيف: ترتيب حسب تاريخ الإنشاء (الأحدث أولاً)
      return b.createdAt.compareTo(a.createdAt);
    });
    return pending;
  }

  List<Task> get hiddenPendingTasks =>
      _hiddenTasks.where((t) => !t.isCompleted).toList();
  List<Task> get hiddenCompletedTasks =>
      _hiddenTasks.where((t) => t.isCompleted).toList();

  // Constructor removed - loadTasks() is called explicitly from SplashScreen

  Future<void> loadTasks({bool showLoading = true, bool notify = true}) async {
    if (showLoading) {
      _isLoading = true;
      if (notify) notifyListeners();
    }

    try {
      _tasks = await _db.getTasks();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      if (notify) notifyListeners();
    }
  }

  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

  Future<void> loadDeletedTasks({
    bool showLoading = true,
    bool notify = true,
  }) async {
    if (showLoading) {
      _isLoading = true;
      if (notify) notifyListeners();
    }

    try {
      _deletedTasks = await _db.getDeletedTasks();
    } catch (e) {
      debugPrint('Error loading deleted tasks: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      if (notify) notifyListeners();
    }
  }

  Future<void> loadSubtasks(String taskId) async {
    _subtasks = await _db.getSubtasksByTaskId(taskId);
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    try {
      debugPrint('=== TaskProvider.addTask START ===');
      debugPrint('Task: ${task.title}');

      await _db.insertTask(task);
      debugPrint('insertTask completed');

      await loadTasks();
      debugPrint('loadTasks completed');
      debugPrint('Total tasks now: ${_tasks.length}');
      debugPrint('=== TaskProvider.addTask SUCCESS ===');
    } catch (e, stackTrace) {
      debugPrint('=== TaskProvider.addTask ERROR ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow; // Re-throw to let UI handle it
    }
  }

  Future<void> updateTask(Task task) async {
    await _db.updateTask(task);
    await loadTasks();
  }

  Future<void> deleteTask(String id) async {
    final task = await _db.getTaskById(id);
    if (task != null && task.reminderTime != null) {
      await NotificationService().cancelTaskNotifications(task.id);
      // Note: AlarmService().cancelScheduledAlarm() cancels all, which is a limitation.
      // But we call it anyway to be safe if it's the current alarm.
      AlarmService().cancelScheduledAlarm();
    }
    await _db.softDeleteTask(id);
    await loadTasks(showLoading: false, notify: false);
    if (task?.isHidden ?? false) {
      await loadHiddenTasks();
    }
    await loadDeletedTasks(showLoading: false, notify: true);
  }

  Future<void> batchDeleteTasks(List<String> ids) async {
    bool anyHidden = false;
    for (final id in ids) {
      final task = await _db.getTaskById(id);
      if (task != null) {
        if (task.isHidden) anyHidden = true;
        if (task.reminderTime != null) {
          await NotificationService().cancelTaskNotifications(task.id);
          AlarmService().cancelScheduledAlarm();
        }
        await _db.softDeleteTask(id);
      }
    }
    await loadTasks(showLoading: false, notify: false);
    if (anyHidden) {
      await loadHiddenTasks();
    }
    await loadDeletedTasks(showLoading: false, notify: true);
  }

  Future<void> restoreTask(String id) async {
    await _db.restoreTask(id);
    final task = await _db.getTaskById(id);
    if (task != null && task.reminderTime != null) {
      // Re-schedule if still relevant
      if (task.reminderTime!.isAfter(DateTime.now()) ||
          task.repeatType != 'none') {
        final next = task.nextOccurrence;
        if (next != null && next.isAfter(DateTime.now()) && !task.isCompleted) {
          await AlarmService().scheduleAlarm(
            scheduledTime: next,
            title: task.title,
            body: task.description,
            priority: task.priority,
            taskId: task.id,
            repeatType: task.repeatType,
            repeatDays: task.repeatDays,
          );
        }
      }
    }
    await loadTasks(showLoading: false, notify: false);
    await loadDeletedTasks(showLoading: false, notify: true);
  }

  Future<void> permanentlyDeleteTask(String id) async {
    final task = await _db.getTaskById(id);
    if (task != null && task.reminderTime != null) {
      await NotificationService().cancelTaskNotifications(task.id);
    }
    await _db.permanentlyDeleteTask(id);
    await loadDeletedTasks(showLoading: false);
  }

  Future<void> restoreTasks(List<String> ids) async {
    await _db.batchRestoreTasks(ids);
    await loadTasks(showLoading: false, notify: false);
    await loadDeletedTasks(showLoading: false, notify: true);
  }

  Future<void> permanentlyDeleteTasks(List<String> ids) async {
    await _db.batchPermanentlyDeleteTasks(ids);
    await loadDeletedTasks(showLoading: false);
  }

  Future<void> toggleTaskCompletion(String id) async {
    // محاولة العثور على المهمة في القائمتين
    Task? task;
    try {
      task = _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      try {
        task = _hiddenTasks.firstWhere((t) => t.id == id);
      } catch (_) {
        debugPrint('Task not found in provider lists, fetching from DB...');
        task = await _db.getTaskById(id);
      }
    }

    if (task == null) return;

    final now = DateTime.now();
    final newIsCompleted = !task.isCompleted;

    if (newIsCompleted && task.reminderTime != null) {
      await NotificationService().cancelTaskNotifications(task.id);
      AlarmService().cancelScheduledAlarm();
    } else if (!newIsCompleted && task.reminderTime != null) {
      if (task.reminderTime!.isAfter(now)) {
        await AlarmService().scheduleAlarm(
          scheduledTime: task.reminderTime!,
          title: task.title,
          body: task.description,
          priority: task.priority,
          taskId: task.id,
          repeatType: task.repeatType,
          repeatDays: task.repeatDays,
        );
      }
    }

    await updateTask(
      task.copyWith(
        isCompleted: newIsCompleted,
        completedAt: newIsCompleted ? now : null,
        updatedAt: now,
      ),
    );

    // تحديث القوائم
    if (task.isHidden) {
      await loadHiddenTasks();
    }
  }

  Future<void> addSubtask(Subtask subtask) async {
    await _db.insertSubtask(subtask);
    await loadSubtasks(subtask.taskId);
  }

  Future<void> toggleSubtaskCompletion(String id) async {
    final subtask = _subtasks.firstWhere((s) => s.id == id);
    await _db.updateSubtask(
      subtask.copyWith(isCompleted: !subtask.isCompleted),
    );
    await loadSubtasks(subtask.taskId);
  }

  Task createNewTask({
    required String title,
    String description = '',
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
  }) {
    final now = DateTime.now();
    return Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      createdAt: now,
      updatedAt: now,
    );
  }

  Subtask createNewSubtask({required String taskId, required String title}) {
    return Subtask(id: const Uuid().v4(), taskId: taskId, title: title);
  }

  Future<void> hideTask(String id) async {
    await _db.hideTask(id);
    await loadTasks();
    await loadHiddenTasks();
  }

  Future<void> showTask(String id) async {
    await _db.showTask(id);
    await loadTasks();
    await loadHiddenTasks();
  }

  Future<void> loadHiddenTasks() async {
    try {
      _hiddenTasks = await _db.getHiddenTasks();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading hidden tasks: $e');
    }
  }
}
