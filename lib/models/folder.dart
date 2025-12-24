import 'package:flutter/material.dart';

class Folder {
  final String id;
  final String name;
  final String? parentId;
  final Color color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.color = Colors.blue,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    Color? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearParentId = false,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'color': color.toARGB32(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
      parentId: map['parentId'],
      color: Color(map['color'] ?? Colors.blue.toARGB32()),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isDeleted: map['isDeleted'] == 1,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'])
          : null,
    );
  }
}
