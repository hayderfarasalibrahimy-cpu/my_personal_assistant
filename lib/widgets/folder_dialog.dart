import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/folder.dart';

class FolderDialog extends StatefulWidget {
  final Folder? folder;
  final String? parentId;

  const FolderDialog({super.key, this.folder, this.parentId});

  @override
  State<FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<FolderDialog> {
  late TextEditingController _nameController;
  Color _selectedColor = Colors.blue;

  final List<Color> _folderColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.amber,
    Colors.teal,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder?.name ?? '');
    _selectedColor = widget.folder?.color ?? Colors.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.folder == null ? 'مجلد جديد' : 'تعديل المجلد',
        style: const TextStyle(fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم المجلد',
                hintText: 'مثلاً: ملاحظات العمل',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('اختر لوناً:', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _folderColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
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
            if (_nameController.text.trim().isEmpty) return;

            final folder =
                widget.folder?.copyWith(
                  name: _nameController.text.trim(),
                  color: _selectedColor,
                ) ??
                Folder(
                  id: const Uuid().v4(),
                  name: _nameController.text.trim(),
                  parentId: widget.parentId,
                  color: _selectedColor,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

            Navigator.pop(context, folder);
          },
          child: Text(widget.folder == null ? 'إضافة' : 'حفظ'),
        ),
      ],
    );
  }
}
