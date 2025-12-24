import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../services/database_service.dart';

class NoteProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Note> _notes = [];
  List<Note> _hiddenNotes = [];
  List<Folder> _folders = [];
  List<Note> _deletedNotes = [];
  List<Folder> _deletedFolders = [];
  bool _isLoading = false;
  String? _currentFolderId;
  List<Folder> _navigationStack = [];
  int _allNotesCount = 0;

  List<Note> get notes => _notes;
  List<Note> get hiddenNotes => _hiddenNotes;
  List<Folder> get folders => _folders;
  List<Note> get deletedNotes => _deletedNotes;
  List<Folder> get deletedFolders => _deletedFolders;
  bool get isLoading => _isLoading;
  String? get currentFolderId => _currentFolderId;
  List<Folder> get navigationStack => _navigationStack;
  int get allNotesCount => _allNotesCount;

  // Constructor removed - loadNotes() is called explicitly from SplashScreen

  Future<void> loadNotes({bool showLoading = true, bool notify = true}) async {
    if (showLoading) {
      _isLoading = true;
      if (notify) notifyListeners();
    }

    try {
      if (_currentFolderId == null) {
        // إذا كنا في المستوى الرئيسي، نجلب الملاحظات التي ليس لها مجلد
        _notes = await _db.getNotesByFolder(null);
      } else {
        _notes = await _db.getNotesByFolder(_currentFolderId);
      }
      // جلب عدد جميع الملاحظات غير المحذوفة للإحصائيات
      final allNotes = await _db.getNotes();
      _allNotesCount = allNotes.length;

      await loadFolders(showLoading: false, notify: false);
    } catch (e) {
      debugPrint('Error loading notes: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      if (notify) notifyListeners();
    }
  }

  Future<void> loadFolders({
    bool showLoading = true,
    bool notify = true,
  }) async {
    if (showLoading) {
      _isLoading = true;
      if (notify) notifyListeners();
    }

    try {
      _folders = await _db.getFolders(parentId: _currentFolderId);
    } catch (e) {
      debugPrint('Error loading folders: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      if (notify) notifyListeners();
    }
  }

  Future<void> setFolder(Folder? folder) async {
    if (folder == null) {
      _currentFolderId = null;
      _navigationStack = [];
    } else {
      _currentFolderId = folder.id;
      if (!_navigationStack.contains(folder)) {
        _navigationStack.add(folder);
      }
    }
    await loadNotes();
  }

  Future<void> navigateBack() async {
    if (_navigationStack.isNotEmpty) {
      _navigationStack.removeLast();
      _currentFolderId = _navigationStack.isEmpty
          ? null
          : _navigationStack.last.id;
      await loadNotes();
    }
  }

  Future<void> addFolder(Folder folder) async {
    await _db.insertFolder(folder);
    await loadFolders();
  }

  Future<void> updateFolder(Folder folder) async {
    await _db.updateFolder(folder);
    await loadFolders();
  }

  Future<void> deleteFolder(String id) async {
    await _db.softDeleteFolder(id);
    await loadFolders();
    await loadDeletedFolders();
  }

  Future<void> loadDeletedFolders() async {
    try {
      _deletedFolders = await _db.getDeletedFolders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading deleted folders: $e');
    }
  }

  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    final note = (await _db.getNoteById(noteId))!;
    final updatedNote = note.copyWith(
      folderId: folderId,
      clearFolderId: folderId == null,
    );
    await _db.updateNote(updatedNote);
    await loadNotes();
  }

  Future<void> loadDeletedNotes({
    bool showLoading = true,
    bool notify = true,
  }) async {
    if (showLoading) {
      _isLoading = true;
      if (notify) notifyListeners();
    }

    try {
      _deletedNotes = await _db.getDeletedNotes();
    } catch (e) {
      debugPrint('Error loading deleted notes: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      if (notify) notifyListeners();
    }
  }

  Future<void> addNote(Note note) async {
    try {
      await _db.insertNote(note);
      await loadNotes();
    } catch (e) {
      debugPrint('Error adding note: $e');
      rethrow; // Re-throw to let UI handle it
    }
  }

  Future<void> updateNote(Note note) async {
    await _db.updateNote(note);
    await loadNotes();
  }

  Future<void> deleteNote(String id) async {
    await _db.softDeleteNote(id);
    await loadNotes(showLoading: false, notify: false);
    await loadDeletedNotes(showLoading: false, notify: true);
  }

  Future<void> batchDeleteNotes(List<String> ids) async {
    for (final id in ids) {
      await _db.softDeleteNote(id);
    }
    await loadNotes(showLoading: false, notify: false);
    await loadDeletedNotes(showLoading: false, notify: true);
  }

  Future<void> batchMoveNotesToFolder(
    List<String> noteIds,
    String? folderId,
  ) async {
    for (final noteId in noteIds) {
      final note = await _db.getNoteById(noteId);
      if (note != null) {
        final updatedNote = note.copyWith(
          folderId: folderId,
          clearFolderId: folderId == null,
        );
        await _db.updateNote(updatedNote);
      }
    }
    await loadNotes();
  }

  Future<void> restoreNote(String id) async {
    await _db.restoreNote(id);
    await loadNotes(showLoading: false, notify: false);
    await loadDeletedNotes(showLoading: false, notify: true);
  }

  Future<void> permanentlyDeleteNote(String id) async {
    await _db.permanentlyDeleteNote(id);
    await loadDeletedNotes(showLoading: false);
  }

  Future<void> restoreNotes(List<String> ids) async {
    for (final id in ids) {
      await _db.restoreNote(id);
    }
    await loadNotes(showLoading: false, notify: false);
    await loadDeletedNotes(showLoading: false, notify: true);
  }

  Future<void> permanentlyDeleteNotes(List<String> ids) async {
    await _db.batchPermanentlyDeleteNotes(ids);
    await loadDeletedNotes(showLoading: false);
  }

  Future<void> toggleNotePinStatus(String id) async {
    final note = _notes.firstWhere((n) => n.id == id);
    await updateNote(
      note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()),
    );
  }

  Future<void> hideNote(String id) async {
    await _db.hideNote(id);
    await loadNotes();
    await loadHiddenNotes();
  }

  Future<void> showNote(String id) async {
    await _db.showNote(id);
    await loadNotes();
    await loadHiddenNotes();
  }

  Future<void> loadHiddenNotes() async {
    try {
      _hiddenNotes = await _db.getHiddenNotes();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading hidden notes: $e');
    }
  }

  Note createNewNote({required String title, String content = ''}) {
    final now = DateTime.now();
    return Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      folderId: _currentFolderId,
      createdAt: now,
      updatedAt: now,
    );
  }
}
