import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../services/vault_service.dart';

import '../utils/app_snackbar.dart';
import 'vault_lock_screen.dart';
import 'vault_settings_screen.dart';
import '../widgets/note_card.dart';
import '../widgets/task_card.dart';
import '../providers/note_provider.dart';
import '../providers/task_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'add_note_screen.dart';
import 'add_task_screen.dart';

/// شاشة الخزينة - عرض العناصر المخفية
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen>
    with SingleTickerProviderStateMixin {
  final VaultService _vaultService = VaultService();
  late TabController _tabController;

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedNoteIds = {};
  final Set<String> _selectedTaskIds = {};

  // 'all', 'pending', 'completed'
  String _taskFilter = 'pending';

  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          // Exit selection mode when changing tabs
          if (_isSelectionMode) {
            _exitSelectionMode();
          }
        });
      }
    });
    _checkAccess();
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      if (_tabController.index == 0) {
        _selectedNoteIds.add(id);
      } else {
        _selectedTaskIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNoteIds.clear();
      _selectedTaskIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_tabController.index == 0) {
        if (_selectedNoteIds.contains(id)) {
          _selectedNoteIds.remove(id);
        } else {
          _selectedNoteIds.add(id);
        }
        if (_selectedNoteIds.isEmpty) _isSelectionMode = false;
      } else {
        if (_selectedTaskIds.contains(id)) {
          _selectedTaskIds.remove(id);
        } else {
          _selectedTaskIds.add(id);
        }
        if (_selectedTaskIds.isEmpty) _isSelectionMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_tabController.index == 0) {
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        if (_selectedNoteIds.length == noteProvider.hiddenNotes.length) {
          _selectedNoteIds.clear();
        } else {
          _selectedNoteIds.addAll(noteProvider.hiddenNotes.map((n) => n.id));
        }
      } else {
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        List<Task> currentTasks;
        // Select logic: Select visible tasks based on filter? Or all hidden tasks?
        // Usually Select All selects all visible items.
        if (_taskFilter == 'pending') {
          currentTasks = taskProvider.hiddenPendingTasks;
        } else if (_taskFilter == 'completed') {
          currentTasks = taskProvider.hiddenCompletedTasks;
        } else {
          currentTasks = taskProvider.hiddenTasks;
        }

        if (_selectedTaskIds.length == currentTasks.length) {
          _selectedTaskIds.clear();
        } else {
          _selectedTaskIds
              .clear(); // Clear first to avoid mixing if we had partial
          _selectedTaskIds.addAll(currentTasks.map((t) => t.id));
        }
      }
    });
  }

  Future<void> _deleteSelected() async {
    final isNotes = _tabController.index == 0;
    final count = isNotes ? _selectedNoteIds.length : _selectedTaskIds.length;
    final itemType = isNotes ? 'ملاحظة' : 'مهمة';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف $count $itemType'),
        content: const Text(
          'هل أنت متأكد من الحذف؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;

    if (isNotes) {
      final provider = Provider.of<NoteProvider>(context, listen: false);
      await provider.batchDeleteNotes(_selectedNoteIds.toList());
    } else {
      final provider = Provider.of<TaskProvider>(context, listen: false);
      await provider.batchDeleteTasks(_selectedTaskIds.toList());
    }
    _exitSelectionMode();
    if (mounted) AppSnackBar.success(context, 'تم حذف المحدد');
  }

  Future<void> _checkAccess() async {
    final isProtected = await _vaultService.isProtectionEnabled();

    if (isProtected && !_vaultService.isUnlocked) {
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VaultLockScreen(
              onUnlocked: () {
                Navigator.pop(context);
                _loadData(); // Load after unlock
              },
            ),
          ),
        );
      }
    } else {
      _vaultService.unlock();
      _checkSetup();
      _loadData();
    }
  }

  Future<void> _checkSetup() async {
    final protectionType = await _vaultService.getProtectionType();
    if (protectionType != VaultProtectionType.none) return;

    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool('vault_setup_asked') ?? false;

    if (!hasAsked && mounted) {
      await prefs.setBool('vault_setup_asked', true);
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حماية الخزينة'),
          content: const Text(
            'هل ترغب في إعداد حماية للخزينة (رمز PIN أو بصمة) للحفاظ على خصوصية بياناتك؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لاحقاً'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إعداد الآن'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VaultSettingsScreen()),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isUnlocked = true;
    });
    // Load data from providers
    if (mounted) {
      await Future.wait([
        Provider.of<NoteProvider>(context, listen: false).loadHiddenNotes(),
        Provider.of<TaskProvider>(context, listen: false).loadHiddenTasks(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('الخزينة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer2<NoteProvider, TaskProvider>(
      builder: (context, noteProvider, taskProvider, child) {
        final selectedCount = _tabController.index == 0
            ? _selectedNoteIds.length
            : _selectedTaskIds.length;

        return PopScope(
          canPop: !_isSelectionMode,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _isSelectionMode) {
              _exitSelectionMode();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: _isSelectionMode ? Colors.green.shade700 : null,
              foregroundColor: _isSelectionMode ? Colors.white : null,
              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _exitSelectionMode,
                    )
                  : null, // Default AutoLeading
              title: _isSelectionMode
                  ? Text(
                      '$selectedCount محددة',
                      style: const TextStyle(fontSize: 16),
                    )
                  : const Text('الخزينة', style: TextStyle(fontSize: 16)),
              actions: _isSelectionMode
                  ? [
                      IconButton(
                        icon: const Icon(Icons.select_all),
                        tooltip: 'تحديد الكل',
                        onPressed: _selectAll,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'حذف',
                        onPressed: selectedCount > 0 ? _deleteSelected : null,
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VaultSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.lock_outline),
                        tooltip: 'قفل الخزينة',
                        onPressed: () {
                          _vaultService.lock();
                          Navigator.pop(context);
                        },
                      ),
                    ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: _isSelectionMode ? Colors.white : null,
                unselectedLabelColor: _isSelectionMode ? Colors.white70 : null,
                indicatorColor: _isSelectionMode ? Colors.white : null,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.note_outlined, size: 18),
                    text: 'ملاحظات (${noteProvider.hiddenNotes.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.task_outlined, size: 18),
                    text: 'مهام (${taskProvider.hiddenTasks.length})',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildNotesList(noteProvider.hiddenNotes),
                _buildTasksList(taskProvider.hiddenTasks),
              ],
            ),
            floatingActionButton: _isSelectionMode
                ? null
                : FloatingActionButton(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Icon(
                      _tabController.index == 0 ? Icons.add : Icons.add_task,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_tabController.index == 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AddNoteScreen(isHidden: true),
                          ),
                        ).then((_) => _loadData());
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AddTaskScreen(isHidden: true),
                          ),
                        ).then((_) => _loadData());
                      }
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildNotesList(List<Note> notes) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'لا توجد ملاحظات مخفية',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isSelected = _selectedNoteIds.contains(note.id);

        return Dismissible(
          key: ValueKey(note.id),
          direction: _isSelectionMode
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('حذف الملاحظة'),
                content: const Text('هل أنت متأكد من حذف هذه الملاحظة؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            Provider.of<NoteProvider>(
              context,
              listen: false,
            ).deleteNote(note.id);
            AppSnackBar.success(context, 'تم حذف الملاحظة');
          },
          child: NoteCard(
            note: note,
            isSelected: isSelected,
            selectionMode: _isSelectionMode,
            onSelectionToggle: () => _toggleSelection(note.id),
            onLongPressSelect: () => _enterSelectionMode(note.id),
            onTap: () {
              // When NOT in selection mode, handle tap normally (handled inside NoteCard if tap callback is null,
              // but we passed one here previously.
              // NoteCard logic: if selectionMode, calls toggle. If not, calls onTap if provided.
              // So we pass the navigation logic here.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddNoteScreen(note: note),
                ),
              ).then((_) => _loadData());
            },
          ),
        );
      },
    );
  }

  Widget _buildTasksList(List<Task> allHiddenTasks) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    List<Task> tasksToShow;
    if (_taskFilter == 'pending') {
      tasksToShow = taskProvider.hiddenPendingTasks;
    } else if (_taskFilter == 'completed') {
      tasksToShow = taskProvider.hiddenCompletedTasks;
    } else {
      tasksToShow = allHiddenTasks;
    }

    return Column(
      children: [
        // Filter Chips - Hide in selection mode? No, kept for context.
        // Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterChip('معلقة', 'pending'),
              const SizedBox(width: 8),
              _buildFilterChip('مكتملة', 'completed'),
              const SizedBox(width: 8),
              _buildFilterChip('الكل', 'all'),
            ],
          ),
        ),

        Expanded(
          child: tasksToShow.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _taskFilter == 'pending'
                            ? 'لا توجد مهام معلقة'
                            : _taskFilter == 'completed'
                            ? 'لا توجد مهام مكتملة'
                            : 'لا توجد مهام مخفية',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tasksToShow.length,
                  itemBuilder: (context, index) {
                    final task = tasksToShow[index];
                    final isSelected = _selectedTaskIds.contains(task.id);

                    return Dismissible(
                      key: ValueKey(task.id),
                      direction: _isSelectionMode
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('حذف المهمة'),
                            content: const Text(
                              'هل أنت متأكد من حذف هذه المهمة؟',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        Provider.of<TaskProvider>(
                          context,
                          listen: false,
                        ).deleteTask(task.id);
                        AppSnackBar.success(context, 'تم حذف المهمة');
                      },
                      child: TaskCard(
                        task: task,
                        isSelected: isSelected,
                        selectionMode: _isSelectionMode,
                        onSelectionToggle: () => _toggleSelection(task.id),
                        onLongPressSelect: () => _enterSelectionMode(task.id),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddTaskScreen(task: task),
                            ),
                          ).then((_) => _loadData());
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _taskFilter == value;
    final primaryColor = Theme.of(context).primaryColor;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false, // Prevent layout shift
      onSelected: (selected) {
        setState(() {
          _taskFilter = value;
        });
      },
      backgroundColor: Colors.transparent,
      selectedColor: primaryColor,
      // Solid color for selected state for clarity
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[600],
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.3),
          width: isSelected ? 0 : 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
