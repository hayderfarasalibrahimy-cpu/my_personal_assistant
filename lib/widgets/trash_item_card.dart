import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/note.dart';
import '../utils/app_theme.dart';

class TrashItemCard extends StatelessWidget {
  final dynamic item; // Task or Note
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TrashItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (item is Task) {
      return _buildTaskCard(context, item as Task);
    } else if (item is Note) {
      return _buildNoteCard(context, item as Note);
    }
    return const SizedBox.shrink();
  }

  Widget _buildTaskCard(BuildContext context, Task task) {
    final priorityColor = AppTheme.getPriorityColor(task.priority.index);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildBaseCard(
      context,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderColor: isSelected
          ? Colors.blue
          : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildLeadingIcon(
          priorityColor: priorityColor,
          iconData: Icons.check_circle_outline,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: TextDecoration.lineThrough,
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            _buildDeletedDate(task.deletedAt, isDark),
          ],
        ),
        trailing: _buildSelectionIndicator(isSelected, isSelectionMode),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final luminance = note.color.computeLuminance();
    final textColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return _buildBaseCard(
      context,
      color: note.color.withValues(alpha: 0.9),
      borderColor: isSelected
          ? (isDark ? Colors.white : Colors.blue)
          : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildLeadingIcon(
          priorityColor: textColor.withValues(alpha: 0.7),
          iconData: Icons.note_outlined,
          iconColor: textColor,
        ),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.lineThrough,
            decorationColor: textColor.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  note.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            _buildDeletedDate(
              note.deletedAt,
              isDark,
              overrideColor: textColor.withValues(alpha: 0.6),
            ),
          ],
        ),
        trailing: _buildSelectionIndicator(
          isSelected,
          isSelectionMode,
          activeColor: isDark ? Colors.white : Colors.blue,
          checkColor: isDark ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildBaseCard(
    BuildContext context, {
    required Color color,
    required Color borderColor,
    required Widget child,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        onTap: isSelectionMode
            ? onTap
            : null, // If selection mode, tap toggles. If not, maybe show details? For now selection only.
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildLeadingIcon({
    required Color priorityColor,
    required IconData iconData,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor ?? priorityColor, size: 20),
    );
  }

  Widget _buildDeletedDate(
    DateTime? date,
    bool isDark, {
    Color? overrideColor,
  }) {
    if (date == null) return const SizedBox.shrink();

    // Calculate relative time (this logic could ideally be in a utility)
    final now = DateTime.now();
    final difference = now.difference(date);
    String timeAgo;

    if (difference.inMinutes < 1) {
      timeAgo = 'الآن';
    } else if (difference.inMinutes < 60) {
      timeAgo = 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      timeAgo = 'منذ ${difference.inHours} ساعة';
    } else {
      timeAgo = 'منذ ${difference.inDays} يوم';
    }

    return Row(
      children: [
        Icon(
          Icons.delete_outline,
          size: 14,
          color: overrideColor ?? (isDark ? Colors.white38 : Colors.grey),
        ),
        const SizedBox(width: 4),
        Text(
          timeAgo,
          style: TextStyle(
            fontSize: 11,
            color: overrideColor ?? (isDark ? Colors.white38 : Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget? _buildSelectionIndicator(
    bool isSelected,
    bool isSelectionMode, {
    Color activeColor = Colors.blue,
    Color checkColor = Colors.white,
  }) {
    if (!isSelectionMode) return null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? activeColor : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? activeColor : Colors.grey,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: isSelected ? Icon(Icons.check, size: 16, color: checkColor) : null,
    );
  }
}
