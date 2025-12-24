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
import '../utils/app_snackbar.dart';

class NoteCard extends StatefulWidget {
  final Note note;

  const NoteCard({super.key, required this.note});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getTextColor(Color background) {
    if (background == Colors.white) return Colors.black87;
    return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);
    SoundService.playDelete();

    await _animationController.forward();

    if (!mounted) return;
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    await noteProvider.deleteNote(widget.note.id);
  }

  void _onCardTap() {
    SoundService.playClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddNoteScreen(note: widget.note)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final textColor = _getTextColor(widget.note.color);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isDeleting ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: _isDeleting ? _fadeAnimation.value : 1.0,
            child: child,
          ),
        );
      },
      child: _buildCard(noteProvider, textColor),
    );
  }

  Widget _buildCard(NoteProvider noteProvider, Color textColor) {
    final cardContent = _buildCardContent(noteProvider, textColor);

    if (BackgroundService.hasBackground()) {
      return GlassContainer(
        blur: 8,
        opacity: 0.4,
        color: widget.note.color,
        child: InkWell(
          onTap: _onCardTap,
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    }

    return Card(
      color: widget.note.color,
      child: InkWell(
        onTap: _onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      ),
    );
  }

  Widget _buildCardContent(NoteProvider noteProvider, Color textColor) {
    // استخدام لون النص الأصلي للملاحظة دائماً، إلا في الوضع الداكن نستخدم الأزرق الغامق
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = isDark
        ? const Color(0xFF0D47A1)
        : textColor; // Dark blue in dark mode as requested

    return Container(
      padding: const EdgeInsets.all(16), // Increased padding
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
        crossAxisAlignment: CrossAxisAlignment.center, // Center alignment
        children: [
          // Header Row (Pin & Copy)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  widget.note.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  size: 20,
                  color: widget.note.isPinned
                      ? Colors.orangeAccent
                      : displayColor.withValues(alpha: 0.5),
                ),
                onPressed: () {
                  SoundService.playClick();
                  noteProvider.toggleNotePinStatus(widget.note.id);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  size: 18,
                  color: displayColor.withValues(alpha: 0.6),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: '${widget.note.title}\n${widget.note.content}',
                    ),
                  );
                  AppSnackBar.info(context, 'تم نسخ الملاحظة');
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Title
          Text(
            widget.note.title,
            textAlign: TextAlign.center, // Center text
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              // Larger title
              fontWeight: FontWeight.w900,
              color: displayColor,
              height: 1.2,
              shadows: isDark
                  ? [
                      Shadow(
                        color: Colors.white.withValues(
                          alpha: 0.3,
                        ), // Lighter shadow for dark text
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Divider decoration
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 12),

          // Content
          Text(
            widget.note.content,
            textAlign: TextAlign.center, // Center text
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: displayColor.withValues(alpha: 0.9),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(), // Push footer down
          const SizedBox(height: 16),

          // Footer (Date & Delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spaced out
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Created Date
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: displayColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'إنشاء: '),
                          TextSpan(
                            text: DateFormat(
                              'dd/MM/yyyy',
                              'en',
                            ).format(widget.note.createdAt),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '  —  '),
                          TextSpan(
                            text: DateFormat('hh:mm a', 'en')
                                .format(widget.note.createdAt)
                                .replaceAll('AM', 'ص')
                                .replaceAll('PM', 'م'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: displayColor.withValues(alpha: 0.9),
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ),

                  // Updated Date (if exists)
                  if (widget.note.updatedAt != widget.note.createdAt)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: displayColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: displayColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'تعديل: '),
                              TextSpan(
                                text: DateFormat(
                                  'dd/MM/yyyy',
                                  'en',
                                ).format(widget.note.updatedAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: '  —  '),
                              TextSpan(
                                text: DateFormat('hh:mm a', 'en')
                                    .format(widget.note.updatedAt)
                                    .replaceAll('AM', 'ص')
                                    .replaceAll('PM', 'م'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: displayColor.withValues(alpha: 0.9),
                                fontSize: 10,
                                height: 1.1,
                              ),
                        ),
                      ),
                    ),
                ],
              ),

              // Delete Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleDelete, // Restore functionality
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    // Removed AnimatedContainer for simplicity or keep it if preferred
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isDeleting
                          ? Colors.red.withValues(alpha: 0.2)
                          : displayColor.withValues(
                              alpha: 0.1,
                            ), // Subtle background
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: _isDeleting
                          ? Colors.red
                          : displayColor.withValues(alpha: 0.7),
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
}
