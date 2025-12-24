import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'file_service.dart';

class BackupService {
  final DatabaseService _dbService = DatabaseService();
  final FileService _fileService = FileService();

  Future<String?> createBackup() async {
    try {
      // 1. الحصول على المسارات
      final dbPath = await _dbService.getDbPath();
      final mediaPath = await _fileService.getMediaPath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('قاعدة البيانات غير موجودة!');
      }

      // 2. إنشاء مجلد مؤقت للعملية (فقط لتجميع الملفات الأساسية إذا لزم الأمر،
      // ولكن يمكننا القراءة مباشرة الآن)
      // سنقرأ الملفات ونضيفها للأرشيف في الذاكرة.

      final archive = Archive();

      // 3. إغلاق قاعدة البيانات
      await _dbService.closeDatabase();

      // 4. إضافة ملف قاعدة البيانات
      final dbBytes = await dbFile.readAsBytes();
      final dbArchiveFile = ArchiveFile(
        'personal_assistant.db',
        dbBytes.lengthInBytes,
        dbBytes,
      );
      archive.addFile(dbArchiveFile);

      // 5. إضافة تفضيلات المستخدم
      final prefs = await SharedPreferences.getInstance();
      final allPrefs = <String, dynamic>{};
      final keys = prefs.getKeys();
      for (String key in keys) {
        allPrefs[key] = prefs.get(key);
      }
      final jsonPrefs = jsonEncode(allPrefs);
      final prefsBytes = utf8.encode(jsonPrefs);
      final prefsArchiveFile = ArchiveFile(
        'shared_preferences.json',
        prefsBytes.length,
        prefsBytes,
      );
      archive.addFile(prefsArchiveFile);

      // 6. إضافة ملفات الوسائط
      final mediaDir = Directory(mediaPath);
      if (await mediaDir.exists()) {
        await for (var entity in mediaDir.list(recursive: true)) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            // نتأكد من أننا نأخذ المسار النسبي داخل مجلد media
            // الهيكل في الأرشيف سيكون: media/filename.ext
            final relativePath = 'media/$fileName';
            final fileBytes = await entity.readAsBytes();
            final mediaFile = ArchiveFile(
              relativePath,
              fileBytes.length,
              fileBytes,
            );
            archive.addFile(mediaFile);
          }
        }
      }

      // 7. تحويل الأرشيف إلى بيانات (ZIP Bytes)
      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);

      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

      // 8. حفظ الملف عبر FilePicker
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية الشاملة',
        fileName: 'backup_full_$timestamp.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: Uint8List.fromList(zipBytes),
      );

      return outputFile;
    } catch (e) {
      rethrow;
    }
    // لم نعد بحاجة لتنظيف tempDir لأننا لم ننشئه لغرض النسخ
  }

  Future<bool> restoreBackup() async {
    Directory? tempDir;
    try {
      // 1. اختيار ملف النسخة الاحتياطية
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف النسخة الاحتياطية (.zip)',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final sourcePath = result.files.single.path!;

      // 2. قراءة الملف وفك الضغط
      final bytes = await File(sourcePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // إنشاء مجلد مؤقت للاستخراج
      final appCacheDir = await getTemporaryDirectory();
      tempDir = await appCacheDir.createTemp('restore_temp');

      // استخراج الملفات
      extractArchiveToDisk(archive, tempDir.path);

      // البحث عن الملفات
      File? foundDbFile;
      File? foundPrefsFile;
      Directory? foundMediaDir;

      // البحث المباشر بناءً على الهيكل المعروف الآن
      final dbFileCheck = File(p.join(tempDir.path, 'personal_assistant.db'));
      if (await dbFileCheck.exists()) foundDbFile = dbFileCheck;

      final prefsFileCheck = File(
        p.join(tempDir.path, 'shared_preferences.json'),
      );
      if (await prefsFileCheck.exists()) foundPrefsFile = prefsFileCheck;

      final mediaDirCheck = Directory(p.join(tempDir.path, 'media'));
      if (await mediaDirCheck.exists()) foundMediaDir = mediaDirCheck;

      if (foundDbFile == null) {
        // محاولة بحث متكرر كحل احتياطي إذا كان هناك مجلد جذر
        await for (final entity in tempDir.list(recursive: true)) {
          if (entity is File) {
            final filename = p.basename(entity.path);
            if (filename == 'personal_assistant.db') foundDbFile = entity;
            if (filename == 'shared_preferences.json') foundPrefsFile = entity;
          } else if (entity is Directory) {
            if (p.basename(entity.path) == 'media') foundMediaDir = entity;
          }
        }
      }

      if (foundDbFile == null) {
        throw Exception('ملف قاعدة البيانات غير موجود في النسخة الاحتياطية');
      }

      // 3. التحضير للاستعادة
      final currentDbPath = await _dbService.getDbPath();
      final currentMediaDirStr = await _fileService.getMediaPath();
      final currentMediaDir = Directory(currentMediaDirStr);

      // 4. إغلاق قاعدة البيانات الحالية
      await _dbService.closeDatabase();
      await Future.delayed(const Duration(milliseconds: 200));

      // 5. استبدال قاعدة البيانات
      await foundDbFile.copy(currentDbPath);

      // 6. استعادة الوسائط (تنظيف القديم واستبداله)
      if (await currentMediaDir.exists()) {
        await currentMediaDir.delete(recursive: true);
      }
      await currentMediaDir.create();

      if (foundMediaDir != null) {
        await _copyDirectory(foundMediaDir, currentMediaDir);
      }

      // 7. استعادة التفضيلات (الإعدادات)
      if (foundPrefsFile != null) {
        final prefsJson = await foundPrefsFile.readAsString();
        final Map<String, dynamic> allPrefs = jsonDecode(prefsJson);
        final prefs = await SharedPreferences.getInstance();

        // مسح الإعدادات الحالية قبل الاستعادة لضمان تطابق كامل (اختياري، لكن أفضل)
        // await prefs.clear(); // يمكن تفعيله اذا اردنا مسح القديم

        for (var entry in allPrefs.entries) {
          final val = entry.value;
          if (val is bool) {
            await prefs.setBool(entry.key, val);
          } else if (val is int) {
            await prefs.setInt(entry.key, val);
          } else if (val is double) {
            await prefs.setDouble(entry.key, val);
          } else if (val is String) {
            await prefs.setString(entry.key, val);
          } else if (val is List) {
            await prefs.setStringList(
              entry.key,
              val.map((e) => e.toString()).toList(),
            );
          }
        }
      }

      return true;
    } catch (e) {
      // ignore: avoid_print
      rethrow;
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(
          p.join(destination.absolute.path, p.basename(entity.path)),
        );
        await newDirectory.create();
        await _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }
}
