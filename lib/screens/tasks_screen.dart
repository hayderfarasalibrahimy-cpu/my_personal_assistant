import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../utils/search_delegates.dart';
import '../services/sound_service.dart';
import '../services/toast_service.dart';
import 'add_task_screen.dart';
import '../models/task.dart';
import '../services/gemini_service.dart';
import '../services/explanation_service.dart';
import '../utils/app_snackbar.dart';
import '../widgets/glass_widgets.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _selectedPriority = 'الكل';
  String _selectedCategory = 'الكل';
  bool _isOrganizing = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};

  void _enterSelectionMode(String taskId) {
    setState(() {
      _isSelectionMode = true;
      _selectedTaskIds.add(taskId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _selectAllTasks(List<Task> tasks) {
    setState(() {
      if (_selectedTaskIds.length == tasks.length) {
        _selectedTaskIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedTaskIds.addAll(tasks.map((t) => t.id));
      }
    });
  }

  Future<void> _deleteSelectedTasks() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final count = _selectedTaskIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف $count مهام؟'),
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

    if (confirm == true) {
      await taskProvider.batchDeleteTasks(_selectedTaskIds.toList());
      _exitSelectionMode();
      if (mounted) {
        AppSnackBar.success(context, 'تم حذف $count مهمة');
      }
    }
  }

  Future<void> _organizeSchedule() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final pendingTasks = taskProvider.pendingTasks;

    if (pendingTasks.isEmpty) {
      if (mounted) {
        AppSnackBar.info(context, 'لا توجد مهام معلقة لتنظيمها');
      }
      return;
    }

    ExplanationService.showExplanationDialog(
      context: context,
      featureKey: 'organize_schedule',
      title: 'تنظيم الجدول بالذكاء الاصطناعي',
      explanation:
          'سأقوم بتحليل مهامك المعلقة وترتيبها لك بشكل ذكي بناءً على الأولوية والمواعيد النهائية، مع تقديم نصيحة لزيادة إنتاجيتك.',
      onProceed: () async {
        setState(() => _isOrganizing = true);
        try {
          final tasksData = pendingTasks
              .map(
                (t) => {
                  'title': t.title,
                  'priority': t.priority.toString().split('.').last,
                  'dueDate': t.dueDate?.toIso8601String() ?? 'غير محدد',
                },
              )
              .toList();

          final suggestion = await GeminiService.organizeSchedule(tasksData);

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'ترتيب المساعد المقترح',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Text(suggestion, style: const TextStyle(fontSize: 13)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('شكراً'),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.error(context, e.toString());
          }
        } finally {
          if (mounted) setState(() => _isOrganizing = false);
        }
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصفية المهام'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الأولوية:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['الكل', 'عالية', 'متوسطة', 'منخفضة'].map((
                    priority,
                  ) {
                    return ChoiceChip(
                      label: Text(priority),
                      selected: _selectedPriority == priority,
                      onSelected: (selected) {
                        setDialogState(() {
                          _selectedPriority = priority;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'التصنيف:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['الكل', 'عمل', 'شخصي', 'دراسة', 'صحة', 'عام'].map((
                    category,
                  ) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setDialogState(() {
                          _selectedCategory = category;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedPriority = 'الكل';
                _selectedCategory = 'الكل';
              });
              Navigator.pop(context);
            },
            child: const Text('إعادة تعيين'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {}); // Trigger rebuild with new filters
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    return tasks.where((task) {
      bool matchesPriority = _selectedPriority == 'الكل';
      if (!matchesPriority) {
        if (_selectedPriority == 'عالية' &&
            task.priority == TaskPriority.high) {
          matchesPriority = true;
        } else if (_selectedPriority == 'متوسطة' &&
            task.priority == TaskPriority.medium) {
          matchesPriority = true;
        } else if (_selectedPriority == 'منخفضة' &&
            task.priority == TaskPriority.low) {
          matchesPriority = true;
        }
      }

      bool matchesCategory =
          _selectedCategory == 'الكل' || task.category == _selectedCategory;
      return matchesPriority && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        _selectedPriority != 'الكل' || _selectedCategory != 'الكل';

    return DefaultTabController(
      length: 3,
      child: PopScope(
        canPop: !_isSelectionMode,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _isSelectionMode) {
            _exitSelectionMode();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: _isSelectionMode
                ? Colors.green.shade700
                : Colors.transparent,
            elevation: 0,
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _exitSelectionMode,
                  )
                : null,
            title: _isSelectionMode
                ? Text(
                    '${_selectedTaskIds.length} محددة',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  )
                : const Text('المهام', style: TextStyle(fontSize: 16)),
            bottom: TabBar(
              labelStyle: const TextStyle(fontSize: 13),
              labelColor: _isSelectionMode ? Colors.white : null,
              unselectedLabelColor: _isSelectionMode ? Colors.white70 : null,
              indicatorColor: _isSelectionMode ? Colors.white : null,
              tabs: const [
                Tab(text: 'معلقة'),
                Tab(text: 'مكتملة'),
                Tab(text: 'الكل'),
              ],
            ),
            actions: _isSelectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.select_all, color: Colors.white),
                      onPressed: () {
                        final taskProvider = Provider.of<TaskProvider>(
                          context,
                          listen: false,
                        );
                        _selectAllTasks(taskProvider.tasks);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                      onPressed: _selectedTaskIds.isEmpty
                          ? null
                          : _deleteSelectedTasks,
                    ),
                  ]
                : [
                    if (_isOrganizing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 20,
                          color: Colors.blue,
                        ),
                        onPressed: _organizeSchedule,
                        tooltip: 'تنظيم المهام بالذكاء الاصطناعي',
                      ),
                    IconButton(
                      icon: const Icon(Icons.search, size: 20),
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () {
                        final tasks = Provider.of<TaskProvider>(
                          context,
                          listen: false,
                        ).tasks;
                        showSearch(
                          context: context,
                          delegate: TaskSearchDelegate(tasks: tasks),
                        );
                      },
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.filter_list, size: 20),
                          iconSize: 20,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: _showFilterDialog,
                        ),
                        if (hasActiveFilters)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
          ),
          body: Consumer<TaskProvider>(
            builder: (context, taskProvider, child) {
              if (taskProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return TabBarView(
                children: [
                  _TaskList(
                    tasks: _filterTasks(taskProvider.pendingTasks),
                    isSelectionMode: _isSelectionMode,
                    selectedTaskIds: _selectedTaskIds,
                    onSelectionToggle: _toggleSelection,
                    onLongPressSelect: _enterSelectionMode,
                  ),
                  _TaskList(
                    tasks: _filterTasks(taskProvider.completedTasks),
                    isSelectionMode: _isSelectionMode,
                    selectedTaskIds: _selectedTaskIds,
                    onSelectionToggle: _toggleSelection,
                    onLongPressSelect: _enterSelectionMode,
                  ),
                  _TaskList(
                    tasks: _filterTasks(taskProvider.tasks),
                    isSelectionMode: _isSelectionMode,
                    selectedTaskIds: _selectedTaskIds,
                    onSelectionToggle: _toggleSelection,
                    onLongPressSelect: _enterSelectionMode,
                  ),
                ],
              );
            },
          ),
          floatingActionButton: _isSelectionMode
              ? null
              : GlassContainer(
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddTaskScreen(),
                        ),
                      );
                    },
                    elevation: 0,
                    backgroundColor: Colors.blue.shade900.withValues(
                      alpha: 0.5,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.add_task, size: 24),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List tasks;
  final bool isSelectionMode;
  final Set<String> selectedTaskIds;
  final Function(String) onSelectionToggle;
  final Function(String) onLongPressSelect;

  const _TaskList({
    required this.tasks,
    required this.isSelectionMode,
    required this.selectedTaskIds,
    required this.onSelectionToggle,
    required this.onLongPressSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'لا توجد مهام',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Dismissible(
          key: ValueKey(task.id),
          background: Container(
            alignment: Alignment
                .centerRight, // Swipe Left (StartToEnd) reveals Right side
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment:
                  MainAxisAlignment.start, // Start = Right in RTL
              children: [
                Icon(Icons.delete_outline, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'حذف',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            alignment: Alignment
                .centerLeft, // Swipe Right (EndToStart) reveals Left side
            padding: const EdgeInsets.only(left: 20),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end, // End = Left in RTL
              children: [
                Text(
                  'حذف',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.delete_outline, color: Colors.white),
              ],
            ),
          ),
          direction: isSelectionMode
              ? DismissDirection.none
              : DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('تأكيد الحذف'),
                content: Text('هل أنت متأكد من حذف "${task.title}"؟'),
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
            final taskProvider = Provider.of<TaskProvider>(
              context,
              listen: false,
            );
            SoundService.playDelete();
            taskProvider.deleteTask(task.id);

            // Use Custom Toast Service
            ToastService.showUndoToast(context, 'تم حذف "${task.title}"', () {
              taskProvider.restoreTask(task.id);
            });
          },
          child: Stack(
            children: [
              TaskCard(
                key: ValueKey(task.id),
                task: task,
                isSelected: selectedTaskIds.contains(task.id),
                selectionMode: isSelectionMode,
                onSelectionToggle: () => onSelectionToggle(task.id),
                onLongPressSelect: () => onLongPressSelect(task.id),
              ),
              // BLOCKING LAYER: Prevents swiping from the center 60% of the card
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: GestureDetector(
                    onHorizontalDragStart:
                        (_) {}, // Absorbs the start of the drag
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
