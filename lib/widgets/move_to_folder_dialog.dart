import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';

class MoveToFolderDialog extends StatefulWidget {
  final String? noteId;
  final String? currentFolderId;
  final bool isBulkMove;

  const MoveToFolderDialog({
    super.key,
    this.noteId,
    this.currentFolderId,
    this.isBulkMove = false,
  });

  @override
  State<MoveToFolderDialog> createState() => _MoveToFolderDialogState();
}

class _MoveToFolderDialogState extends State<MoveToFolderDialog> {
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.currentFolderId;
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);

    return AlertDialog(
      title: Text(
        widget.isBulkMove ? 'نقل الملاحظات المحددة' : 'نقل إلى مجلد',
        style: const TextStyle(fontSize: 16),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('المستوى الرئيسي'),
              selected: _selectedFolderId == null,
              onTap: () => setState(() => _selectedFolderId = null),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: noteProvider.folders.length,
                itemBuilder: (context, index) {
                  final folder = noteProvider.folders[index];
                  return ListTile(
                    leading: Icon(Icons.folder, color: folder.color),
                    title: Text(folder.name),
                    selected: _selectedFolderId == folder.id,
                    onTap: () => setState(() => _selectedFolderId = folder.id),
                  );
                },
              ),
            ),
            if (noteProvider.folders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'لا توجد مجلدات أخرى',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (widget.isBulkMove) {
              // إرجاع المجلد المختار للـ bulk move
              Navigator.pop(context, _selectedFolderId ?? 'root');
            } else {
              // التنفيذ المباشر للملاحظة الواحدة
              if (widget.noteId != null) {
                noteProvider.moveNoteToFolder(
                  widget.noteId!,
                  _selectedFolderId,
                );
              }
              Navigator.pop(context);
            }
          },
          child: const Text('نقل'),
        ),
      ],
    );
  }
}
