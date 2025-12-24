import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../utils/app_theme.dart';
import '../services/sound_service.dart';
import '../services/background_service.dart';
import '../services/assistant_service.dart';
import 'glass_widgets.dart';
import 'package:intl/intl.dart';
import '../screens/add_task_screen.dart';
import '../utils/app_snackbar.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPressSelect;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.isSelected = false,
    this.selectionMode = false,
    this.onSelectionToggle,
    this.onLongPressSelect,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  bool _isCompleting = false;
  late AnimationController _hintController;
  late Animation<Offset> _hintAnimation;
  Timer? _countdownTimer;

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

    // بدء المؤقت لتحديث العداد التنازلي كل ثانية
    if (widget.task.reminderTime != null && !widget.task.isCompleted) {
      _startTimer();
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _hintController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إعادة تشغيل المؤقت إذا تغير التنبيه أو حالة الإكمال
    if (widget.task.reminderTime != oldWidget.task.reminderTime ||
        widget.task.isCompleted != oldWidget.task.isCompleted) {
      if (widget.task.reminderTime != null && !widget.task.isCompleted) {
        _startTimer();
      } else {
        _countdownTimer?.cancel();
      }
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    return AppTheme.getPriorityColor(priority.index);
  }

  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.critical:
        return '🔴 حرجة';
      case TaskPriority.high:
        return '⚡ عالية';
      case TaskPriority.medium:
        return '⚠️ متوسطة';
      case TaskPriority.low:
        return '🟢 منخفضة';
    }
  }

  Future<void> _handleDelete() async {
    // تشغيل انيميشن التلميح
    SoundService.playClick();
    await _hintController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await _hintController.reverse();
    }
  }

  Future<void> _handleToggleCompletion() async {
    setState(() => _isCompleting = true);

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    // صوت مختلف حسب الحالة
    if (!widget.task.isCompleted) {
      SoundService.playSuccess();
      AssistantService().showSuccess(); // تفاعل الروبوت مع الإنجاز

      // فحص إذا تم إكمال جميع المهام بعد هذا الإنجاز
      await taskProvider.toggleTaskCompletion(widget.task.id);

      // التحقق من عدد المهام المعلقة
      if (taskProvider.pendingTasks.isEmpty) {
        // احتفال عند إكمال جميع المهام!
        AssistantService().showCelebrate();
      }
    } else {
      SoundService.playClick();
      await taskProvider.toggleTaskCompletion(widget.task.id);
    }

    if (mounted) {
      setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Priority color
    final priorityColor = _getPriorityColor(widget.task.priority);

    Widget card = _buildCard(priorityColor);

    // إضافة دائرة التحديد
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
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
  }

  Widget _buildCard(Color priorityColor) {
    final cardContent = _buildCardContent(priorityColor);

    // Hint Background
    final hintBackground = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [
          Icon(Icons.swipe_left, color: Colors.white, size: 28),
          SizedBox(width: 8),
          Text(
            'اسحب للحذف',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );

    // Border Color logic
    Color borderColor;
    double borderWidth;
    if (widget.isSelected) {
      borderColor = Colors.green;
      borderWidth = 2.5;
    } else {
      borderColor = Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.85);
      borderWidth = 1.2;
    }

    final card = BackgroundService.hasBackground()
        ? GlassContainer(
            blur: 10,
            opacity: 0.15,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.green.withValues(alpha: 0.8)
                  : Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.9),
              width: borderWidth,
            ),
            child: InkWell(
              onTap: _onCardTap,
              onLongPress: _onCardLongPress,
              borderRadius: BorderRadius.circular(16),
              child: cardContent,
            ),
          )
        : Card(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: borderWidth),
            ),
            elevation: widget.isSelected ? 4 : 1,
            shadowColor: widget.isSelected
                ? Colors.green.withValues(alpha: 0.4)
                : null,
            child: InkWell(
              onTap: _onCardTap,
              onLongPress: _onCardLongPress,
              borderRadius: BorderRadius.circular(16),
              child: cardContent,
            ),
          );

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
      MaterialPageRoute(builder: (context) => AddTaskScreen(task: widget.task)),
    );
  }

  void _onCardLongPress() {
    if (widget.selectionMode) {
      widget.onLongPressSelect?.call();
    } else {
      _showOptions();
    }
  }

  void _showOptions() {
    SoundService.playClick();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل المهمة'),
              onTap: () {
                Navigator.pop(context);
                _onCardTap();
              },
            ),
            if (!widget.task.isHidden)
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.purple),
                title: const Text(
                  'نقل إلى الخزينة',
                  style: TextStyle(color: Colors.purple),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final taskProvider = Provider.of<TaskProvider>(
                    context,
                    listen: false,
                  );
                  await taskProvider.hideTask(widget.task.id);
                  if (context.mounted) {
                    AppSnackBar.success(
                      context,
                      'تم نقل "${widget.task.title}" للخزينة',
                    );
                  }
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.lock_open, color: Colors.purple),
                title: const Text(
                  'إرجاع للعرض العام',
                  style: TextStyle(color: Colors.purple),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final taskProvider = Provider.of<TaskProvider>(
                    context,
                    listen: false,
                  );
                  await taskProvider.showTask(widget.task.id);
                  if (context.mounted) {
                    AppSnackBar.success(
                      context,
                      'تم إرجاع "${widget.task.title}" للعرض العام',
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                // استخدام Provider للحذف الفعلي
                final taskProvider = Provider.of<TaskProvider>(
                  context,
                  listen: false,
                );
                await taskProvider.deleteTask(widget.task.id);
                if (context.mounted) {
                  AppSnackBar.success(context, 'تم حذف المهمة');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(Color priorityColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(8), // Extreme reduction
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header: Centered Checkbox & Priority on the side
          Row(
            children: [
              // Spacer to keep checkbox in center
              const Expanded(child: SizedBox()),

              // Animated Checkbox (Centered and Enlarged with reduced opacity)
              Opacity(
                opacity: 0.7, // Reduced visibility
                child: AnimatedScale(
                  scale: _isCompleting ? 1.4 : 1.1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: widget.task.isCompleted
                          ? [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: widget.task.isCompleted,
                        onChanged: (_) => _handleToggleCompletion(),
                        activeColor: Colors.green,
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide(
                          color: widget.task.isCompleted
                              ? Colors.green
                              : priorityColor,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Priority Indicator on the end
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: priorityColor, width: 1.5),
                    ),
                    child: Text(
                      _getPriorityText(widget.task.priority),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4), // Reduced
          // Title Section with Background - Compact
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ), // Reduced
            decoration: BoxDecoration(
              color: (widget.task.isCompleted ? Colors.grey : priorityColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8), // Reduced
              border: Border.all(
                color: (widget.task.isCompleted ? Colors.grey : priorityColor)
                    .withValues(alpha: 0.3),
                width: 1, // Thinner
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      decoration: widget.task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: widget.task.isCompleted ? Colors.grey : textColor,
                    ),
                    textAlign: TextAlign.center,
                    child: Text(widget.task.title),
                  ),
                ),
                Positioned(
                  left: -8,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.copy,
                      size: 10,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.task.title));
                      AppSnackBar.info(context, 'تم النسخ');
                    },
                  ),
                ),
              ],
            ),
          ),

          // Description Section with Background
          if (widget.task.description.isNotEmpty) ...[
            const SizedBox(height: 4), // Reduced
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ), // Reduced
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 60),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          widget.task.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: textColor.withValues(alpha: 0.8),
                                fontSize: 9, // Smaller
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -8,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.copy,
                        size: 9, // Tinier
                        color: textColor.withValues(alpha: 0.4),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.task.description),
                        );
                        AppSnackBar.info(context, 'تم النسخ');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4), // Reduced
          // Dates Section with Background - Compact
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ), // Reduced
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Created Date - with Time
                if (widget.task.createdAt == widget.task.updatedAt)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 9, // Tinier
                        color: Colors.blue[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'أضيفت: ${DateFormat('dd/MM/yy hh:mm a').format(widget.task.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[400],
                          fontSize: 7, // Tinier
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                // Updated Date - with Time
                if (widget.task.updatedAt != widget.task.createdAt) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_calendar,
                        size: 9,
                        color: Colors.blue[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'عُدلت: ${DateFormat('dd/MM/yy hh:mm a').format(widget.task.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[400],
                          fontSize: 7,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                // Due Date
                if (widget.task.dueDate != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 9,
                        color: Colors.orange[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'استحقاق: ${DateFormat('dd/MM/yy').format(widget.task.dueDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[400],
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // عرض تفاصيل التذكير والعداد التنازلي
          if (widget.task.reminderTime != null && !widget.task.isCompleted) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ), // Tight
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        size: 9,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'موعد التنبيه: ${DateFormat('dd/MM hh:mm a').format(widget.task.reminderTime!)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getRemainingTimeText(widget.task.nextOccurrence!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace', // للعداد الثابت
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4), // Reduced
          // Delete button only
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleDelete,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4), // Tight
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 14, // Smaller
                      color: Colors.grey,
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

  String _getRemainingTimeText(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now);

    if (difference.isNegative) {
      return '(فات الموعد)';
    }

    // حساب التفاصيل
    int seconds = difference.inSeconds % 60;
    int minutes = difference.inMinutes % 60;
    int hours = difference.inHours % 24;
    int days = difference.inDays % 30;
    int months = (difference.inDays / 30).floor();

    List<String> parts = [];
    if (months > 0) parts.add('$months شهر');
    if (days > 0) parts.add('$days يوم');
    if (hours > 0) parts.add('$hours س');
    if (minutes > 0) parts.add('$minutes د');
    parts.add('$seconds ث');

    return 'الوقت المتبقي: ${parts.join(' : ')}';
  }
}
