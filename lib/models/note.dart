import 'package:flutter/material.dart';
import 'dart:convert';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final String? categoryId;
  final Color color;
  final List<String> audioPaths;
  final List<String> imagePaths;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? folderId;
  final bool isHidden; // للخزينة

  Note({
    required this.id,
    required this.title,
    this.content = '',
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.categoryId,
    this.color = Colors.white,
    this.audioPaths = const [],
    this.imagePaths = const [],
    this.isDeleted = false,
    this.deletedAt,
    this.folderId,
    this.isHidden = false,
  });

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    String? categoryId,
    Color? color,
    List<String>? audioPaths,
    List<String>? imagePaths,
    bool? isDeleted,
    DateTime? deletedAt,
    String? folderId,
    bool? isHidden,
    bool clearDeletedAt = false,
    bool clearFolderId = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isPinned: isPinned ?? this.isPinned,
      categoryId: categoryId ?? this.categoryId,
      color: color ?? this.color,
      audioPaths: audioPaths ?? this.audioPaths,
      imagePaths: imagePaths ?? this.imagePaths,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned ? 1 : 0,
      'categoryId': categoryId,
      'color': color.toARGB32(),
      'audioPaths': jsonEncode(audioPaths),
      'imagePaths': jsonEncode(imagePaths),
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
      'folderId': folderId,
      'isHidden': isHidden ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    List<String> audioPathsList = [];
    if (map['audioPaths'] != null && map['audioPaths'] is String) {
      try {
        audioPathsList = List<String>.from(jsonDecode(map['audioPaths']));
      } catch (e) {
        audioPathsList = [];
      }
    }
    // التوافق مع البيانات القديمة
    if (map['audioPath'] != null &&
        map['audioPath'] is String &&
        map['audioPath'].isNotEmpty) {
      if (!audioPathsList.contains(map['audioPath'])) {
        audioPathsList.add(map['audioPath']);
      }
    }

    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isPinned: map['isPinned'] == 1,
      categoryId: map['categoryId'],
      color: Color(map['color'] ?? Colors.white.toARGB32()),
      audioPaths: audioPathsList,
      imagePaths: map['imagePaths'] != null
          ? List<String>.from(jsonDecode(map['imagePaths']))
          : [],
      isDeleted: map['isDeleted'] == 1,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'])
          : null,
      folderId: map['folderId'],
      isHidden: map['isHidden'] == 1,
    );
  }
}
