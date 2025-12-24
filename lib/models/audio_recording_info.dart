import 'dart:convert';

/// معلومات التسجيل الصوتي
class AudioRecordingInfo {
  final String path;
  final DateTime recordedAt;
  final int durationSeconds;
  final String? title;

  AudioRecordingInfo({
    required this.path,
    required this.recordedAt,
    required this.durationSeconds,
    this.title,
  });

  /// إنشاء من JSON
  factory AudioRecordingInfo.fromJson(Map<String, dynamic> json) {
    return AudioRecordingInfo(
      path: json['path'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      title: json['title'] as String?,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'recordedAt': recordedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'title': title,
    };
  }

  /// تحويل قائمة من JSON string
  static List<AudioRecordingInfo> listFromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(jsonString);
      return list.map((e) => AudioRecordingInfo.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// تحويل قائمة إلى JSON string
  static String listToJsonString(List<AudioRecordingInfo> list) {
    return json.encode(list.map((e) => e.toJson()).toList());
  }

  /// تنسيق المدة (mm:ss)
  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// تنسيق التاريخ
  String get formattedDate {
    return '${recordedAt.day}/${recordedAt.month}/${recordedAt.year}';
  }

  /// تنسيق الوقت
  String get formattedTime {
    return '${recordedAt.hour.toString().padLeft(2, '0')}:${recordedAt.minute.toString().padLeft(2, '0')}';
  }

  /// العنوان أو اسم افتراضي
  String getTitle(int index) {
    return title ?? 'تسجيل ${index + 1}';
  }
}
