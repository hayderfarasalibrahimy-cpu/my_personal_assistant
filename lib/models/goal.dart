class Goal {
  final String id;
  final String title;
  final String description;
  final DateTime? targetDate;
  final int progress; // 0-100
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.title,
    this.description = '',
    this.targetDate,
    this.progress = 0,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? targetDate,
    int? progress,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDate: targetDate ?? this.targetDate,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetDate': targetDate?.toIso8601String(),
      'progress': progress,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      targetDate: map['targetDate'] != null
          ? DateTime.parse(map['targetDate'])
          : null,
      progress: map['progress'] ?? 0,
      isCompleted: map['isCompleted'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
