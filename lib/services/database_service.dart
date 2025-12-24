import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../models/note.dart';
import '../models/category.dart' as models;
import '../models/goal.dart';
import '../models/folder.dart' as models;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'personal_assistant.db');

    return await openDatabase(
      path,
      version: 13, // إصدار 13: إضافة الخزينة (isHidden)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // إضافة عمود category للمهام
      await _safeAddColumn(db, 'tasks', 'category', 'TEXT DEFAULT "عام"');
      // إضافة عمود color للملاحظات
      await _safeAddColumn(db, 'notes', 'color', 'INTEGER DEFAULT 4294967295');
    }
    if (oldVersion < 3) {
      // إضافة أعمدة الوسائط للإصدار 3
      await _safeAddColumn(db, 'tasks', 'audioPath', 'TEXT');
      await _safeAddColumn(db, 'notes', 'audioPath', 'TEXT');
      await _safeAddColumn(db, 'notes', 'imagePaths', 'TEXT');
    }
    if (oldVersion < 4) {
      // إضافة عمود imagePaths للمهام في الإصدار 4
      await _safeAddColumn(db, 'tasks', 'imagePaths', 'TEXT');
    }
    if (oldVersion < 5) {
      // إصدار 5: دعم تعدد المقاطع الصوتية
      await _safeAddColumn(db, 'tasks', 'audioPaths', 'TEXT');
      await _safeAddColumn(db, 'notes', 'audioPaths', 'TEXT');
    }
    if (oldVersion < 6) {
      // إصدار 6: إضافة categoryId للملاحظات
      await _safeAddColumn(db, 'notes', 'categoryId', 'TEXT');
    }
    if (oldVersion < 7) {
      // إصدار 7: سلة المحذوفات
      await _safeAddColumn(db, 'notes', 'isDeleted', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'notes', 'deletedAt', 'TEXT');
    }
    if (oldVersion < 8) {
      // إصدار 8: إضافة المجلدات
      await db.execute('''
        CREATE TABLE folders (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          parentId TEXT,
          color INTEGER,
          createdAt TEXT,
          updatedAt TEXT,
          isDeleted INTEGER DEFAULT 0,
          deletedAt TEXT
        )
      ''');
      await _safeAddColumn(db, 'notes', 'folderId', 'TEXT');
    }
    if (oldVersion < 9) {
      // إصدار 9: إضافة repeatType للمهام
      await _safeAddColumn(db, 'tasks', 'repeatType', 'TEXT DEFAULT "none"');
    }
    if (oldVersion < 10) {
      // إصدار 10: التأكد من وجود أعمدة الوسائط للمهام
      await _safeAddColumn(db, 'tasks', 'imagePaths', 'TEXT');
      await _safeAddColumn(db, 'tasks', 'audioPaths', 'TEXT');
    }
    if (oldVersion < 11) {
      // إصدار 11: التأكد النهائي من وجود الأعمدة
      await _safeAddColumn(db, 'tasks', 'imagePaths', 'TEXT');
    }

    if (oldVersion < 12) {
      await _safeAddColumn(db, 'tasks', 'repeatDays', 'TEXT DEFAULT "[]"');
    }

    if (oldVersion < 13) {
      // إصدار 13: إضافة الخزينة (إخفاء الملاحظات والمهام)
      await _safeAddColumn(db, 'notes', 'isHidden', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'tasks', 'isHidden', 'INTEGER DEFAULT 0');
    }
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    // التحقق من وجود العمود مسبقاً لتجنب الأخطاء التي قد توقف الترقية
    final result = await db.rawQuery('PRAGMA table_info($table)');
    final exists = result.any((col) => col['name'] == column);

    if (!exists) {
      debugPrint('Adding column $column to table $table');
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } else {
      debugPrint('Column $column already exists in table $table');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tasks table
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        dueDate TEXT,
        reminderTime TEXT,
        priority INTEGER,
        status INTEGER,
        isCompleted INTEGER,
        completedAt TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        category TEXT,
        audioPath TEXT,
        audioPaths TEXT,
        imagePaths TEXT,
        isDeleted INTEGER DEFAULT 0,
        deletedAt TEXT,
        repeatType TEXT DEFAULT "none",
        repeatDays TEXT DEFAULT "[]",
        isHidden INTEGER DEFAULT 0
      )
    ''');

    // Subtasks table
    await db.execute('''
      CREATE TABLE subtasks (
        id TEXT PRIMARY KEY,
        taskId TEXT NOT NULL,
        title TEXT NOT NULL,
        isCompleted INTEGER,
        FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    // Notes table
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT,
        color INTEGER,
        isPinned INTEGER,
        createdAt TEXT,
        updatedAt TEXT,
        audioPath TEXT,
        categoryId TEXT,
        audioPaths TEXT,
        imagePaths TEXT,
        isDeleted INTEGER DEFAULT 0,
        deletedAt TEXT,
        folderId TEXT,
        isHidden INTEGER DEFAULT 0
      )
    ''');

    // Folders table
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parentId TEXT,
        color INTEGER,
        createdAt TEXT,
        updatedAt TEXT,
        isDeleted INTEGER DEFAULT 0,
        deletedAt TEXT
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER,
        icon INTEGER
      )
    ''');

    // Goals table
    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        targetDate TEXT,
        progress INTEGER,
        isCompleted INTEGER,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');
  }

  // ==================== TASKS ====================
  Future<List<Task>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM tasks 
      WHERE (isDeleted != 1 OR isDeleted IS NULL)
        AND (isHidden != 1 OR isHidden IS NULL)
      ORDER BY createdAt DESC
    ''');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<Task?> getTaskById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<List<Task>> getPendingTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where:
          'isCompleted = ? AND (isDeleted = ? OR isDeleted IS NULL) AND (isHidden = ? OR isHidden IS NULL)',
      whereArgs: [0, 0, 0],
      orderBy: 'dueDate ASC',
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<List<Task>> getCompletedTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where:
          'isCompleted = ? AND (isDeleted = ? OR isDeleted IS NULL) AND (isHidden = ? OR isHidden IS NULL)',
      whereArgs: [1, 0, 0],
      orderBy: 'completedAt DESC',
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<void> insertTask(Task task) async {
    try {
      final db = await database;
      await db.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('insertTask ERROR: $e');
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> softDeleteTask(String id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isDeleted': 1, 'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreTask(String id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentlyDeleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> batchPermanentlyDeleteTasks(List<String> ids) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<void> batchRestoreTasks(List<String> ids) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.update(
          'tasks',
          {'isDeleted': 0, 'deletedAt': null},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<List<Task>> getDeletedTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'isDeleted = ?',
      whereArgs: [1],
      orderBy: 'deletedAt DESC',
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  // ==================== SUBTASKS ====================
  Future<List<Subtask>> getSubtasksByTaskId(String taskId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'subtasks',
      where: 'taskId = ?',
      whereArgs: [taskId],
    );
    return List.generate(maps.length, (i) => Subtask.fromMap(maps[i]));
  }

  Future<void> insertSubtask(Subtask subtask) async {
    final db = await database;
    await db.insert(
      'subtasks',
      subtask.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSubtask(Subtask subtask) async {
    final db = await database;
    await db.update(
      'subtasks',
      subtask.toMap(),
      where: 'id = ?',
      whereArgs: [subtask.id],
    );
  }

  Future<void> deleteSubtask(String id) async {
    final db = await database;
    await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== NOTES ====================
  Future<List<Note>> getNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM notes 
      WHERE (isDeleted != 1 OR isDeleted IS NULL)
      ORDER BY isPinned DESC, updatedAt DESC
    ''');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<Note?> getNoteById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> softDeleteNote(String id) async {
    final db = await database;
    await db.update(
      'notes',
      {'isDeleted': 1, 'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreNote(String id) async {
    final db = await database;
    await db.update(
      'notes',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentlyDeleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> batchPermanentlyDeleteNotes(List<String> ids) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<void> batchRestoreNotes(List<String> ids) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.update(
          'notes',
          {'isDeleted': 0, 'deletedAt': null},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<List<Note>> getDeletedNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'isDeleted = ?',
      whereArgs: [1],
      orderBy: 'deletedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<List<Note>> getNotesByFolder(String? folderId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: folderId == null
          ? 'folderId IS NULL AND (isDeleted != 1 OR isDeleted IS NULL) AND (isHidden != 1 OR isHidden IS NULL)'
          : 'folderId = ? AND (isDeleted != 1 OR isDeleted IS NULL) AND (isHidden != 1 OR isHidden IS NULL)',
      whereArgs: folderId == null ? null : [folderId],
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // ==================== VAULT (الخزينة) ====================
  Future<void> hideNote(String id) async {
    final db = await database;
    await db.update('notes', {'isHidden': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> showNote(String id) async {
    final db = await database;
    await db.update('notes', {'isHidden': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getHiddenNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'isHidden = ? AND (isDeleted != 1 OR isDeleted IS NULL)',
      whereArgs: [1],
      orderBy: 'updatedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<void> hideTask(String id) async {
    final db = await database;
    await db.update('tasks', {'isHidden': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> showTask(String id) async {
    final db = await database;
    await db.update('tasks', {'isHidden': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> getHiddenTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'isHidden = ? AND (isDeleted != 1 OR isDeleted IS NULL)',
      whereArgs: [1],
      orderBy: 'updatedAt DESC',
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  // ==================== FOLDERS ====================
  Future<List<models.Folder>> getFolders({String? parentId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      where: parentId == null
          ? 'parentId IS NULL AND (isDeleted != 1 OR isDeleted IS NULL)'
          : 'parentId = ? AND (isDeleted != 1 OR isDeleted IS NULL)',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => models.Folder.fromMap(maps[i]));
  }

  Future<void> insertFolder(models.Folder folder) async {
    final db = await database;
    await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFolder(models.Folder folder) async {
    final db = await database;
    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> softDeleteFolder(String id) async {
    final db = await database;
    await db.update(
      'folders',
      {'isDeleted': 1, 'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentlyDeleteFolder(String id) async {
    final db = await database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<models.Folder>> getDeletedFolders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      where: 'isDeleted = ?',
      whereArgs: [1],
      orderBy: 'deletedAt DESC',
    );
    return List.generate(maps.length, (i) => models.Folder.fromMap(maps[i]));
  }

  // ==================== CATEGORIES ====================
  Future<List<models.Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) => models.Category.fromMap(maps[i]));
  }

  Future<void> insertCategory(models.Category category) async {
    final db = await database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== GOALS ====================
  Future<List<Goal>> getGoals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'goals',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Goal.fromMap(maps[i]));
  }

  Future<void> insertGoal(Goal goal) async {
    final db = await database;
    await db.insert(
      'goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGoal(Goal goal) async {
    final db = await database;
    await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<void> deleteGoal(String id) async {
    final db = await database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== DATA MANAGEMENT ====================
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('subtasks');
    await db.delete('notes');
    await db.delete('categories');
    await db.delete('goals');
  }

  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<String> getDbPath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'personal_assistant.db');
  }
}
