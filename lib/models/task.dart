import 'dart:convert';

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final DateTime? reminderTime;
  final TaskPriority priority;
  final TaskStatus status;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? categoryId;
  final String category; // التصنيف كنص
  final List<String> audioPaths;
  final List<String> imagePaths; // مسارات الصور
  final bool isDeleted;
  final DateTime? deletedAt;
  final String repeatType;
  final List<int> repeatDays;
  final bool isHidden; // للخزينة

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.reminderTime,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.category = 'عام',
    this.audioPaths = const [],
    this.imagePaths = const [],
    this.isDeleted = false,
    this.deletedAt,
    this.repeatType = 'none',
    this.repeatDays = const [],
    this.isHidden = false,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? reminderTime,
    bool clearReminderTime = false,
    TaskPriority? priority,
    TaskStatus? status,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryId,
    String? category,
    List<String>? audioPaths,
    List<String>? imagePaths,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? repeatType,
    List<int>? repeatDays,
    bool? isHidden,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      reminderTime: clearReminderTime
          ? null
          : (reminderTime ?? this.reminderTime),
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(), // دائماً تحديث الوقت عند التعديل
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      audioPaths: audioPaths ?? this.audioPaths,
      imagePaths: imagePaths ?? this.imagePaths,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
      'priority': priority.index,
      'status': status.index,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'category': category,
      'audioPaths': jsonEncode(audioPaths),
      'imagePaths': jsonEncode(imagePaths),
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
      'repeatType': repeatType,
      'repeatDays': jsonEncode(repeatDays),
      'isHidden': isHidden ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    List<String> imagePathsList = [];
    if (map['imagePaths'] != null && map['imagePaths'] is String) {
      try {
        imagePathsList = List<String>.from(jsonDecode(map['imagePaths']));
      } catch (e) {
        imagePathsList = [];
      }
    }

    List<String> audioPathsList = [];
    // محاولة قراءة القائمة الجديدة
    if (map['audioPaths'] != null && map['audioPaths'] is String) {
      try {
        audioPathsList = List<String>.from(jsonDecode(map['audioPaths']));
      } catch (e) {
        audioPathsList = [];
      }
    }
    // التوافق مع البيانات القديمة: إذا كان هناك مسار قديم، أضفه للقائمة
    if (map['audioPath'] != null &&
        map['audioPath'] is String &&
        map['audioPath'].isNotEmpty) {
      if (!audioPathsList.contains(map['audioPath'])) {
        audioPathsList.add(map['audioPath']);
      }
    }

    List<int> repeatDaysList = [];
    if (map['repeatDays'] != null && map['repeatDays'] is String) {
      try {
        final parsed = jsonDecode(map['repeatDays']);
        if (parsed is List) {
          repeatDaysList = parsed.map((e) => e as int).toList();
        }
      } catch (e) {
        repeatDaysList = [];
      }
    }

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      reminderTime: map['reminderTime'] != null
          ? DateTime.parse(map['reminderTime'])
          : null,
      priority: TaskPriority.values[map['priority'] ?? 1],
      status: TaskStatus.values[map['status'] ?? 0],
      isCompleted: map['isCompleted'] == 1,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      category: map['category'] ?? 'عام',
      audioPaths: audioPathsList,
      imagePaths: imagePathsList,
      isDeleted: map['isDeleted'] == 1,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'])
          : null,
      repeatType: map['repeatType'] ?? 'none',
      repeatDays: repeatDaysList,
      isHidden: map['isHidden'] == 1,
    );
  }

  DateTime? get nextOccurrence {
    if (reminderTime == null) return null;
    if (repeatType == 'none') return reminderTime;

    final now = DateTime.now();
    DateTime next = reminderTime!;

    if (repeatType == 'daily') {
      while (next.isBefore(now)) {
        next = next.add(const Duration(days: 1));
      }
    } else if (repeatType == 'weekly') {
      while (next.isBefore(now)) {
        next = next.add(const Duration(days: 7));
      }
    } else if (repeatType == 'weekdays' || repeatType == 'custom') {
      // default weekdays = Mon..Fri إذا لم تُحدد أيام
      final days = repeatDays.isNotEmpty
          ? repeatDays
          : const <int>[1, 2, 3, 4, 5];

      // اجعل next في المستقبل
      while (!next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }

      // تحرك للأمام حتى يصبح اليوم ضمن الأيام المختارة
      while (!days.contains(next.weekday)) {
        next = next.add(const Duration(days: 1));
      }
    }

    return next;
  }
}

enum TaskPriority {
  low, // منخفضة
  medium, // متوسطة
  high, // عالية
  critical, // حرجة
}

enum TaskStatus {
  pending, // قيد الانتظار
  inProgress, // قيد التنفيذ
  completed, // مكتملة
}
