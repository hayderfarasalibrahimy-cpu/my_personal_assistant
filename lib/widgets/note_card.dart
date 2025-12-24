import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../services/sound_service.dart';
import '../services/background_service.dart';
import 'glass_widgets.dart';
import 'package:intl/intl.dart';
import '../screens/add_note_screen.dart';
import 'move_to_folder_dialog.dart';
import '../utils/app_snackbar.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPressSelect;
  final VoidCallback? onTap;

  const NoteCard({
    super.key,
    required this.note,
    this.isSelected = false,
    this.selectionMode = false,
    this.onSelectionToggle,
    this.onLongPressSelect,
    this.onTap,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hintController;
  late Animation<Offset> _hintAnimation;

  @override
  void initState() {
    super.initState();
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _hintAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.6, 0.0), // Slide left 60%
        ).animate(
          CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  Color _getTextColor(Color background) {
    if (background == Colors.white) return Colors.black87;
    return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  Future<void> _handleDelete() async {
    // تشغيل انيميشن التلميح بدلاً من SnackBar
    SoundService.playClick();
    await _hintController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await _hintController.reverse();
    }
  }

  void _onCardTap() {
    if (widget.selectionMode) {
      widget.onSelectionToggle?.call();
      return;
    }
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    SoundService.playClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddNoteScreen(note: widget.note)),
    );
  }

  void _onCardLongPress() {
    if (widget.selectionMode) {
      if (widget.onLongPressSelect != null) {
        widget.onLongPressSelect!();
      }
    } else {
      _showNoteOptions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final textColor = _getTextColor(widget.note.color);

    Widget card = _buildCard(noteProvider, textColor);

    // إضافة دائرة التحديد (تظهر دائماً للسماح بالدخول في وضع التحديد)
    card = Stack(
      children: [
        card,
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              // إذا لم نكن في وضع التحديد، ندخل فيه
              if (!widget.selectionMode) {
                widget.onLongPressSelect?.call();
              } else {
                widget.onSelectionToggle?.call();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected
                    ? Colors.green
                    : widget.selectionMode
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.08),
                border: Border.all(
                  color: widget.isSelected
                      ? Colors.white
                      : widget.selectionMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: widget.isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ],
    );

    // تم إزالة LongPressDraggable بناءً على طلب المستخدم
    return card;
  }

  Widget _buildCard(NoteProvider noteProvider, Color textColor) {
    final cardContent = _buildCardContent(noteProvider, textColor);

    // Hint Background
    final hintBackground = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Start = Right in RTL
        children: const [
          Icon(Icons.swipe_left, color: Colors.white, size: 20),
          SizedBox(width: 6),
          Text(
            'اسحب للحذف',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    Widget card;
    if (BackgroundService.hasBackground()) {
      card = GlassContainer(
        blur: 8,
        opacity: 0.4,
        color: widget.note.color,
        border: widget.isSelected
            ? Border.all(color: Colors.green, width: 3)
            : null,
        child: InkWell(
          onTap: _onCardTap,
          onLongPress: _onCardLongPress,
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    } else {
      card = Card(
        color: widget.note.color,
        elevation: 6,
        shadowColor: _getTextColor(widget.note.color).withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: widget.isSelected
                ? Colors.green
                : _getTextColor(widget.note.color).withValues(alpha: 0.7),
            width: widget.isSelected ? 3 : 3,
          ),
        ),
        child: InkWell(
          onTap: _onCardTap,
          onLongPress: _showNoteOptions,
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: _hintController,
            child: hintBackground,
          ),
        ),
        SlideTransition(position: _hintAnimation, child: card),
      ],
    );
  }

  Widget _buildCardContent(NoteProvider noteProvider, Color textColor) {
    // استخدام لون النص الأصلي للملاحظة دائماً، إلا في الوضع الداكن نستخدم الأزرق الغامق
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = isDark
        ? const Color(0xFF0D47A1)
        : textColor; // Dark blue in dark mode as requested

    return Container(
      padding: const EdgeInsets.all(8), // Extreme reduction
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header Row (Pin & Copy) - Centered to avoid selection circle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  widget.note.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  size: 14,
                  color: widget.note.isPinned
                      ? Colors.orangeAccent
                      : displayColor.withValues(alpha: 0.5),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () {
                  SoundService.playClick();
                  noteProvider.toggleNotePinStatus(widget.note.id);
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.copy,
                  size: 12,
                  color: displayColor.withValues(alpha: 0.6),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: '${widget.note.title}\n${widget.note.content}',
                    ),
                  );
                  AppSnackBar.info(context, 'تم النسخ');
                },
              ),
            ],
          ),

          const SizedBox(height: 4), // Reduced
          // Title with Background - Compact
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ), // Reduced
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8), // Reduced radius
              border: Border.all(
                color: displayColor.withValues(alpha: 0.35),
                width: 1, // Thinner border
              ),
            ),
            child: Text(
              widget.note.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: displayColor,
                height: 1.1,
                fontSize: 11, // Smaller
                shadows: isDark
                    ? [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 4), // Reduced
          // Content with Background - Expanded
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ), // Reduced
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8), // Reduced radius
                border: Border.all(
                  color: displayColor.withValues(alpha: 0.25),
                  width: 1, // Thinner
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  widget.note.content,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: displayColor.withValues(alpha: 0.9),
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    fontSize: 9, // Smaller
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6), // Reduced
          // Footer (Date & Delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Created Date
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1, // Very tight
                      ),
                      decoration: BoxDecoration(
                        color: displayColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12), // Tighter pill
                        border: Border.all(
                          color: displayColor.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'إنشاء: '),
                            TextSpan(
                              text: DateFormat(
                                'dd/MM/yy hh:mm a',
                              ).format(widget.note.createdAt),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: displayColor.withValues(alpha: 0.9),
                          fontSize: 7, // Tinier
                          height: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Updated Date (if exists)
                    if (widget.note.updatedAt != widget.note.createdAt)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: displayColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: displayColor.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'تعديل: '),
                                TextSpan(
                                  text: DateFormat(
                                    'dd/MM/yy hh:mm a',
                                  ).format(widget.note.updatedAt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: displayColor.withValues(alpha: 0.9),
                                  fontSize: 7, // Tinier
                                  height: 1.0,
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // Move Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showMoveDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.drive_file_move_outlined,
                      size: 14,
                      color: displayColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Delete Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleDelete,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(4), // Tight
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 14, // Smaller
                      color: displayColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMoveDialog() {
    SoundService.playClick();
    showDialog(
      context: context,
      builder: (context) => MoveToFolderDialog(
        noteId: widget.note.id,
        currentFolderId: widget.note.folderId,
      ),
    );
  }

  void _showNoteOptions() {
    SoundService.playClick();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل الملاحظة'),
              onTap: () {
                Navigator.pop(context);
                _onCardTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('نقل إلى مجلد'),
              onTap: () {
                Navigator.pop(context);
                _showMoveDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.purple),
              title: const Text(
                'نقل إلى الخزينة',
                style: TextStyle(color: Colors.purple),
              ),
              onTap: () async {
                Navigator.pop(context);
                final noteProvider = Provider.of<NoteProvider>(
                  context,
                  listen: false,
                );
                await noteProvider.hideNote(widget.note.id);
                if (context.mounted) {
                  AppSnackBar.success(
                    context,
                    'تم نقل "${widget.note.title}" للخزينة',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
