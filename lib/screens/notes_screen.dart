import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../widgets/note_card.dart';
import '../utils/search_delegates.dart';
import '../utils/app_snackbar.dart';
import '../services/sound_service.dart';
import 'add_note_screen.dart';
import '../services/toast_service.dart';
import '../widgets/folder_card.dart';
import '../widgets/folder_dialog.dart';
import '../widgets/move_to_folder_dialog.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../widgets/glass_widgets.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _isGridView = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedNoteIds = {};

  void _enterSelectionMode(String noteId) {
    setState(() {
      _isSelectionMode = true;
      _selectedNoteIds.add(noteId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  void _toggleSelection(String noteId) {
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
        if (_selectedNoteIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  void _selectAllNotes(NoteProvider noteProvider) {
    setState(() {
      if (_selectedNoteIds.length == noteProvider.notes.length) {
        _selectedNoteIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedNoteIds.addAll(noteProvider.notes.map((n) => n.id));
      }
    });
  }

  Future<void> _deleteSelectedNotes(NoteProvider noteProvider) async {
    final count = _selectedNoteIds.length;
    await noteProvider.batchDeleteNotes(_selectedNoteIds.toList());
    _exitSelectionMode();
    if (mounted) {
      AppSnackBar.success(context, 'تم حذف $count ملاحظة');
    }
  }

  Future<void> _moveSelectedNotes() async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => MoveToFolderDialog(
        noteId: _selectedNoteIds.first,
        currentFolderId: null,
        isBulkMove: true,
      ),
    );
    if (result != null && mounted) {
      await noteProvider.batchMoveNotesToFolder(
        _selectedNoteIds.toList(),
        result == 'root' ? null : result,
      );
      _exitSelectionMode();
      if (mounted) {
        AppSnackBar.success(context, 'تم نقل الملاحظات');
      }
    }
  }

  AppBar _buildNormalAppBar(NoteProvider noteProvider) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text('الملاحظات', style: TextStyle(fontSize: 16)),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          onPressed: () {
            showSearch(
              context: context,
              delegate: NoteSearchDelegate(notes: noteProvider.notes),
            );
          },
        ),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: 20),
          onPressed: () {
            SoundService.playClick();
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(NoteProvider noteProvider) {
    return AppBar(
      backgroundColor: Colors.green.shade700,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selectedNoteIds.length} محددة',
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _selectedNoteIds.length == noteProvider.notes.length
                ? Icons.deselect
                : Icons.select_all,
            color: Colors.white,
          ),
          tooltip: _selectedNoteIds.length == noteProvider.notes.length
              ? 'إلغاء تحديد الكل'
              : 'تحديد الكل',
          onPressed: () => _selectAllNotes(noteProvider),
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_outlined, color: Colors.white),
          tooltip: 'نقل إلى مجلد',
          onPressed: _selectedNoteIds.isEmpty ? null : _moveSelectedNotes,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          tooltip: 'حذف',
          onPressed: _selectedNoteIds.isEmpty
              ? null
              : () => _deleteSelectedNotes(noteProvider),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteProvider = Provider.of<NoteProvider>(context);

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _isSelectionMode
            ? _buildSelectionAppBar(noteProvider)
            : _buildNormalAppBar(noteProvider),
        body: Column(
          children: [
            // Breadcrumbs
            if (noteProvider.navigationStack.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => noteProvider.setFolder(null),
                      child: const Icon(Icons.home, size: 18),
                    ),
                    const Icon(Icons.chevron_left, size: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: noteProvider.navigationStack
                              .asMap()
                              .entries
                              .map((entry) {
                                final index = entry.key;
                                final folder = entry.value;
                                final isLast =
                                    index ==
                                    noteProvider.navigationStack.length - 1;

                                return Row(
                                  children: [
                                    InkWell(
                                      onTap: isLast
                                          ? null
                                          : () =>
                                                noteProvider.setFolder(folder),
                                      child: Text(
                                        folder.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isLast
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isLast
                                              ? null
                                              : theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      const Icon(Icons.chevron_left, size: 16),
                                  ],
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      onPressed: () => noteProvider.navigateBack(),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: noteProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : noteProvider.notes.isEmpty && noteProvider.folders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            noteProvider.currentFolderId == null
                                ? Icons.note_outlined
                                : Icons.folder_open,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            noteProvider.currentFolderId == null
                                ? 'لا توجد ملاحظات'
                                : 'هذا المجلد فارغ',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                  ? _buildGridView(noteProvider)
                  : _buildListView(noteProvider),
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'add_folder',
              onPressed: () async {
                SoundService.playClick();
                final result = await showDialog<Folder>(
                  context: context,
                  builder: (context) =>
                      FolderDialog(parentId: noteProvider.currentFolderId),
                );
                if (result != null) {
                  noteProvider.addFolder(result);
                }
              },
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: const Icon(Icons.create_new_folder_outlined, size: 20),
            ),
            const SizedBox(height: 12),
            GlassContainer(
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(18),
              blur: 15,
              opacity: 0.1,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              child: FloatingActionButton(
                heroTag: 'add_note',
                onPressed: () {
                  SoundService.playClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddNoteScreen(),
                    ),
                  );
                },
                elevation: 0,
                backgroundColor: Colors.amber.shade900.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.note_add, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(NoteProvider noteProvider) {
    final folders = noteProvider.folders;
    final notes = noteProvider.notes;

    return GridView.builder(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: folders.length + notes.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          return FolderCard(
            folder: folder,
            isGridView: true,
            onTap: () => noteProvider.setFolder(folder),
            onLongPress: () =>
                _showFolderOptions(context, noteProvider, folder),
          );
        }

        final noteIndex = index - folders.length;
        final note = notes[noteIndex];
        return _buildDismissibleNote(context, noteProvider, note);
      },
    );
  }

  Widget _buildListView(NoteProvider noteProvider) {
    final folders = noteProvider.folders;
    final notes = noteProvider.notes;

    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.all(8),
      itemCount: folders.length + notes.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          return FolderCard(
            folder: folder,
            isGridView: false,
            onTap: () => noteProvider.setFolder(folder),
            onLongPress: () =>
                _showFolderOptions(context, noteProvider, folder),
          );
        }

        final noteIndex = index - folders.length;
        final note = notes[noteIndex];
        return _buildDismissibleNote(context, noteProvider, note);
      },
    );
  }

  Widget _buildDismissibleNote(
    BuildContext context,
    NoteProvider noteProvider,
    Note note,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: _isGridView ? 0 : 8),
      child: Dismissible(
        key: ValueKey(note.id),
        direction: DismissDirection.horizontal,
        background: _buildDismissBackground(Alignment.centerRight),
        secondaryBackground: _buildDismissBackground(Alignment.centerLeft),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: Text('هل أنت متأكد من حذف "${note.title}"؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('حذف'),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) {
          SoundService.playDelete();
          noteProvider.deleteNote(note.id);
          ToastService.showUndoToast(
            context,
            'تم حذف "${note.title}"',
            () => noteProvider.restoreNote(note.id),
          );
        },
        child: Stack(
          children: [
            _isGridView
                ? NoteCard(
                    key: ValueKey(note.id),
                    note: note,
                    isSelected: _selectedNoteIds.contains(note.id),
                    selectionMode: _isSelectionMode,
                    onSelectionToggle: () => _toggleSelection(note.id),
                    onLongPressSelect: () => _enterSelectionMode(note.id),
                  )
                : SizedBox(
                    height: 155,
                    child: NoteCard(
                      key: ValueKey(note.id),
                      note: note,
                      isSelected: _selectedNoteIds.contains(note.id),
                      selectionMode: _isSelectionMode,
                      onSelectionToggle: () => _toggleSelection(note.id),
                      onLongPressSelect: () => _enterSelectionMode(note.id),
                    ),
                  ),
            // BLOCKING LAYER: Prevents swiping from the center 60% of the card
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GestureDetector(
                  onHorizontalDragStart: (_) {},
                  behavior: HitTestBehavior.translucent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissBackground(Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  void _showFolderOptions(
    BuildContext context,
    NoteProvider noteProvider,
    Folder folder,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل المجلد'),
              onTap: () async {
                Navigator.pop(context);
                final result = await showDialog<Folder>(
                  context: context,
                  builder: (context) => FolderDialog(folder: folder),
                );
                if (result != null) {
                  noteProvider.updateFolder(result);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'حذف المجلد',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                noteProvider.deleteFolder(folder.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
