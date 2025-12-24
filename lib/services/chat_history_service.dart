import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// خدمة حفظ سجل المحادثات
class ChatHistoryService {
  static Database? _database;
  static bool _initialized = false;

  /// تهيئة sqflite للـ Desktop (Windows/Linux/macOS)
  static void _initSqfliteFfi() {
    if (_initialized) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _initialized = true;
  }

  /// تهيئة قاعدة البيانات
  static Future<void> initialize() async {
    if (_database != null) return;

    _initSqfliteFfi();

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chat_history.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            is_user INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            session_id TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE user_preferences (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// حفظ رسالة جديدة
  static Future<void> saveMessage({
    required String content,
    required bool isUser,
    required String sessionId,
  }) async {
    await initialize();

    await _database!.insert('messages', {
      'content': content,
      'is_user': isUser ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
      'session_id': sessionId,
    });
  }

  /// استرجاع آخر N رسالة للسياق
  static Future<List<Map<String, dynamic>>> getRecentMessages({
    int limit = 20,
    String? sessionId,
  }) async {
    await initialize();

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (sessionId != null) {
      whereClause = 'WHERE session_id = ?';
      whereArgs = [sessionId];
    }

    return await _database!.rawQuery(
      'SELECT * FROM messages $whereClause ORDER BY timestamp DESC LIMIT ?',
      [...whereArgs, limit],
    );
  }

  /// حفظ تفضيل للمستخدم (مثل: المواضيع المفضلة، طريقة التحدث، إلخ)
  static Future<void> savePreference(String key, String value) async {
    await initialize();

    await _database!.insert('user_preferences', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// استرجاع تفضيل معين
  static Future<String?> getPreference(String key) async {
    await initialize();

    final result = await _database!.query(
      'user_preferences',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  /// استرجاع جميع التفضيلات
  static Future<Map<String, String>> getAllPreferences() async {
    await initialize();

    final result = await _database!.query('user_preferences');

    return Map.fromEntries(
      result.map((r) => MapEntry(r['key'] as String, r['value'] as String)),
    );
  }

  /// بناء ملخص تفضيلات المستخدم للـ System Prompt
  static Future<String> buildUserPreferencesSummary() async {
    final prefs = await getAllPreferences();
    final msgs = await getRecentMessages(limit: 10);

    if (prefs.isEmpty && msgs.isEmpty) {
      return '';
    }

    StringBuffer summary = StringBuffer();
    summary.writeln('\n--- معلومات إضافية عن المستخدم ---');

    if (prefs.isNotEmpty) {
      summary.writeln('تفضيلاته المحفوظة:');
      prefs.forEach((key, value) {
        summary.writeln('- $key: $value');
      });
    }

    if (msgs.isNotEmpty) {
      summary.writeln(
        'ملخص آخر محادثاته: المستخدم يتحدث عادةً عن مواضيع متنوعة.',
      );
    }

    return summary.toString();
  }

  /// مسح السجل
  static Future<void> clearHistory() async {
    await initialize();
    await _database!.delete('messages');
  }

  /// إغلاق قاعدة البيانات
  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
