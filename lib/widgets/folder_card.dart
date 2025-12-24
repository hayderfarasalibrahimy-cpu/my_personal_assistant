import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folder.dart';
import '../providers/note_provider.dart';
import '../services/sound_service.dart';
import '../utils/app_snackbar.dart';

class FolderCard extends StatefulWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isGridView;

  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onLongPress,
    this.isGridView = true,
  });

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isDragOver = true);
        return true;
      },
      onLeave: (_) {
        setState(() => _isDragOver = false);
      },
      onAcceptWithDetails: (details) async {
        setState(() => _isDragOver = false);
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        await noteProvider.moveNoteToFolder(details.data, widget.folder.id);
        if (context.mounted) {
          AppSnackBar.success(
            context,
            'تم نقل الملاحظة إلى "${widget.folder.name}"',
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        if (widget.isGridView) {
          return _buildGridCard(theme);
        } else {
          return _buildListCard(theme);
        }
      },
    );
  }

  Widget _buildGridCard(ThemeData theme) {
    return Card(
      elevation: _isDragOver ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isDragOver
              ? Colors.green
              : widget.folder.color.withValues(alpha: 0.5),
          width: _isDragOver ? 3 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          SoundService.playClick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isDragOver ? Icons.folder_open : Icons.folder,
              size: 48,
              color: _isDragOver ? Colors.green : widget.folder.color,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                widget.folder.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(ThemeData theme) {
    return Card(
      elevation: _isDragOver ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isDragOver
              ? Colors.green
              : widget.folder.color.withValues(alpha: 0.3),
          width: _isDragOver ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () {
          SoundService.playClick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        leading: Icon(
          _isDragOver ? Icons.folder_open : Icons.folder,
          color: _isDragOver ? Colors.green : widget.folder.color,
        ),
        title: Text(
          widget.folder.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}
