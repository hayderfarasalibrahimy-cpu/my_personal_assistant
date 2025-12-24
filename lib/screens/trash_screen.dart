import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/note_provider.dart';
import '../services/toast_service.dart';
import '../widgets/trash_item_card.dart';
import '../models/task.dart'; // Needed for TaskPriority enum
import 'package:intl/intl.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedItemIds = {};
  bool _isSelectionMode = false;

  // Filter states
  String _searchQuery = '';
  String _sortOption = 'date_desc'; // date_desc, date_asc, name_asc, name_desc
  String _limitTime = 'all'; // all, today, week, month, custom
  DateTimeRange? _customDateRange;
  TaskPriority? _filterPriority; // null = all
  bool _filterHasImages = false;
  bool _filterHasAudio = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        // When tab settles, just rebuild/clear selection?
        // Better UX: Clear selection on tab change to avoid confusion
        if (_selectedItemIds.isNotEmpty) {
          setState(() {
            _exitSelectionMode();
          });
        }
      }
    });

    // Load deleted items when screen opens
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<TaskProvider>(context, listen: false).loadDeletedTasks();
      Provider.of<NoteProvider>(context, listen: false).loadDeletedNotes();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
        if (_selectedItemIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItemIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedItemIds.add(id);
    });
  }

  void _enableSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedItemIds.clear();
    });
  }

  void _selectAll(List<String> allIds) {
    setState(() {
      if (_selectedItemIds.length == allIds.length) {
        _selectedItemIds.clear();
      } else {
        _selectedItemIds.addAll(allIds);
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selectedItemIds.isEmpty) return;

    final isTaskTab = _tabController.index == 0;
    if (isTaskTab) {
      await Provider.of<TaskProvider>(
        context,
        listen: false,
      ).restoreTasks(_selectedItemIds.toList());
    } else {
      if (!mounted) return;
      await Provider.of<NoteProvider>(
        context,
        listen: false,
      ).restoreNotes(_selectedItemIds.toList());
    }
    _exitSelectionMode();
    if (mounted) {
      ToastService.showSuccessToast(context, 'تمت الاستعادة بنجاح');
    }
  }

  Future<void> _deleteSelectedForever() async {
    if (_selectedItemIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نهائي'),
        content: Text(
          'هل أنت متأكد من حذف ${_selectedItemIds.length} عنصر/عناصر نهائياً؟ لا يمكن التراجع عن هذا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final isTaskTab = _tabController.index == 0;
      if (isTaskTab) {
        await Provider.of<TaskProvider>(
          context,
          listen: false,
        ).permanentlyDeleteTasks(_selectedItemIds.toList());
      } else {
        if (!mounted) return;
        await Provider.of<NoteProvider>(
          context,
          listen: false,
        ).permanentlyDeleteNotes(_selectedItemIds.toList());
      }
      _exitSelectionMode();
      if (mounted) {
        ToastService.showSuccessToast(context, 'تم الحذف نهائياً');
      }
    }
  }

  bool _shouldShowItem(dynamic item) {
    // 1. Media Filters
    if (_filterHasImages) {
      if (item.imagePaths.isEmpty) return false;
    }
    if (_filterHasAudio) {
      if (item.audioPaths.isEmpty) return false;
    }

    // 2. Time Filter
    final deletedAt = item.deletedAt as DateTime?;
    if (deletedAt == null) return true; // Fail safe

    final now = DateTime.now();
    final diff = now.difference(deletedAt);

    if (_limitTime == 'today' && diff.inDays > 0) return false;
    if (_limitTime == 'week' && diff.inDays > 7) return false;
    if (_limitTime == 'month' && diff.inDays > 30) return false;
    if (_limitTime == 'custom' && _customDateRange != null) {
      if (deletedAt.isBefore(_customDateRange!.start) ||
          deletedAt.isAfter(
            _customDateRange!.end.add(const Duration(days: 1)),
          )) {
        // End of day buffer
        return false;
      }
    }

    // 3. Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final title = (item.title as String).toLowerCase();
      final content = item is Task
          ? item.description.toLowerCase()
          : (item as dynamic).content.toLowerCase();

      if (!title.contains(query) && !content.contains(query)) {
        return false;
      }
    }

    // 4. Priority Filter (Tasks Only)
    if (_filterPriority != null && item is Task) {
      if (item.priority != _filterPriority) return false;
    }

    return true;
  }

  int _compareItems(dynamic a, dynamic b) {
    switch (_sortOption) {
      case 'date_asc':
        return (a.deletedAt ?? DateTime(0)).compareTo(
          b.deletedAt ?? DateTime(0),
        );
      case 'name_asc':
        return (a.title as String).compareTo(b.title as String);
      case 'name_desc':
        return (b.title as String).compareTo(a.title as String);
      case 'date_desc':
      default:
        return (b.deletedAt ?? DateTime(0)).compareTo(
          a.deletedAt ?? DateTime(0),
        );
    }
  }

  Future<void> _pickDateRange(StateSetter setSheetState) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
    );
    if (picked != null) {
      setSheetState(() {
        _customDateRange = picked;
        _limitTime = 'custom';
      });
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height for better visibility
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تصفية وفرز',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _sortOption = 'date_desc';
                          _limitTime = 'all';
                          _customDateRange = null;
                          _filterPriority = null;
                          _filterHasImages = false;
                          _filterHasAudio = false;
                        });
                      },
                      child: const Text('إعادة تعيين'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sort Option
                const Text(
                  'الترتيب:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'الأحدث حذفاً',
                      selected: _sortOption == 'date_desc',
                      onSelected: () =>
                          setSheetState(() => _sortOption = 'date_desc'),
                    ),
                    _buildFilterChip(
                      label: 'الأقدم حذفاً',
                      selected: _sortOption == 'date_asc',
                      onSelected: () =>
                          setSheetState(() => _sortOption = 'date_asc'),
                    ),
                    _buildFilterChip(
                      label: 'الاسم (أ-ي)',
                      selected: _sortOption == 'name_asc',
                      onSelected: () =>
                          setSheetState(() => _sortOption = 'name_asc'),
                    ),
                  ],
                ),
                const Divider(),

                // Time Filter
                const Text(
                  'الوقت:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'الكل',
                      selected: _limitTime == 'all',
                      onSelected: () => setSheetState(() => _limitTime = 'all'),
                    ),
                    _buildFilterChip(
                      label: 'اليوم',
                      selected: _limitTime == 'today',
                      onSelected: () =>
                          setSheetState(() => _limitTime = 'today'),
                    ),
                    _buildFilterChip(
                      label: 'الأسبوع',
                      selected: _limitTime == 'week',
                      onSelected: () =>
                          setSheetState(() => _limitTime = 'week'),
                    ),
                    _buildFilterChip(
                      label: _customDateRange != null
                          ? '${DateFormat('M/d').format(_customDateRange!.start)} - ${DateFormat('M/d').format(_customDateRange!.end)}'
                          : 'تاريخ مخصص',
                      selected: _limitTime == 'custom',
                      onSelected: () => _pickDateRange(setSheetState),
                    ),
                  ],
                ),
                const Divider(),

                // Media Content Filter
                const Text(
                  'المحتوى:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: '🖼️ صور',
                      selected: _filterHasImages,
                      onSelected: () => setSheetState(
                        () => _filterHasImages = !_filterHasImages,
                      ),
                    ),
                    _buildFilterChip(
                      label: '🎤 صوتيات',
                      selected: _filterHasAudio,
                      onSelected: () => setSheetState(
                        () => _filterHasAudio = !_filterHasAudio,
                      ),
                    ),
                  ],
                ),

                // Priority Filter (Only show if tasks tab is active)
                if (_tabController.index == 0) ...[
                  const Divider(),
                  const Text(
                    'الأولوية:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'الكل',
                        selected: _filterPriority == null,
                        onSelected: () =>
                            setSheetState(() => _filterPriority = null),
                      ),
                      _buildFilterChip(
                        label: '🟢 منخفضة',
                        selected: _filterPriority == TaskPriority.low,
                        onSelected: () => setSheetState(
                          () => _filterPriority = TaskPriority.low,
                        ),
                      ),
                      _buildFilterChip(
                        label: '🟡 متوسطة',
                        selected: _filterPriority == TaskPriority.medium,
                        onSelected: () => setSheetState(
                          () => _filterPriority = TaskPriority.medium,
                        ),
                      ),
                      _buildFilterChip(
                        label: '🟠 عالية',
                        selected: _filterPriority == TaskPriority.high,
                        onSelected: () => setSheetState(
                          () => _filterPriority = TaskPriority.high,
                        ),
                      ),
                      _buildFilterChip(
                        label: '🔴 حرجة',
                        selected: _filterPriority == TaskPriority.critical,
                        onSelected: () => setSheetState(
                          () => _filterPriority = TaskPriority.critical,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Apply filters to parent
                      Navigator.pop(context);
                    },
                    child: const Text('تطبيق الفلتر'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: selected
            ? Colors.blue
            : Theme.of(context).textTheme.bodyMedium?.color,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTasksList(), _buildNotesList()],
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: _buildSearchBar(),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'المهام', icon: Icon(Icons.check_circle_outline, size: 18)),
          Tab(text: 'الملاحظات', icon: Icon(Icons.note_outlined, size: 18)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.checklist, size: 20),
          iconSize: 20,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: 'تحديد',
          onPressed: _enableSelectionMode,
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.filter_list, size: 20),
              iconSize: 20,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'تصفية',
              onPressed: _showFilterSheet,
            ),
            if (_limitTime != 'all' ||
                _filterPriority != null ||
                _filterHasImages ||
                _filterHasAudio)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'بحث في المحذوفات...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white70),
        icon: Icon(Icons.search, color: Colors.white70),
      ),
      style: const TextStyle(color: Colors.white),
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    // Determine if all are selected to show correct icon state if needed,
    // but simplify to just a "Select All" button action.
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedItemIds.length} محدد'),
      backgroundColor: Colors.blueGrey,
      actions: [
        IconButton(
          icon: const Icon(Icons.restore),
          tooltip: 'استعادة المحدد',
          onPressed: _restoreSelected,
        ),
        IconButton(
          icon: const Icon(Icons.delete_forever),
          tooltip: 'حذف نهائي',
          onPressed: _deleteSelectedForever,
        ),
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: 'تحديد الكل',
          onPressed: () {
            if (_tabController.index == 0) {
              final tasks = Provider.of<TaskProvider>(
                context,
                listen: false,
              ).deletedTasks;
              // Filter visible tasks too if we want "Select Visible"
              // For now, simpler to select ALL meaningful items in the provider for this tab.
              // Better: select only currently visible filtered items.
              final visible = tasks
                  .where(_shouldShowItem)
                  .map((e) => e.id)
                  .toList();
              _selectAll(visible);
            } else {
              final notes = Provider.of<NoteProvider>(
                context,
                listen: false,
              ).deletedNotes;
              final visible = notes
                  .where(_shouldShowItem)
                  .map((e) => e.id)
                  .toList();
              _selectAll(visible);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTasksList() {
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var tasks = provider.deletedTasks.where(_shouldShowItem).toList();
        tasks.sort(_compareItems);

        if (tasks.isEmpty) {
          if (_searchQuery.isNotEmpty ||
              _limitTime != 'all' ||
              _filterHasImages ||
              _filterHasAudio ||
              _filterPriority != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد نتائج تطابق الفلتر',
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _limitTime = 'all';
                        _filterHasImages = false;
                        _filterHasAudio = false;
                        _filterPriority = null;
                        _customDateRange = null;
                      });
                    },
                    child: const Text('إلغاء التصفية'),
                  ),
                ],
              ),
            );
          }
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'سلة المهام فارغة',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final isSelected = _selectedItemIds.contains(task.id);
            return TrashItemCard(
              item: task,
              isSelected: isSelected,
              isSelectionMode: _isSelectionMode,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(task.id);
                }
              },
              onLongPress: () => _enterSelectionMode(task.id),
            );
          },
        );
      },
    );
  }

  Widget _buildNotesList() {
    return Consumer<NoteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var notes = provider.deletedNotes.where(_shouldShowItem).toList();
        notes.sort(_compareItems);

        if (notes.isEmpty) {
          if (_searchQuery.isNotEmpty ||
              _limitTime != 'all' ||
              _filterHasImages ||
              _filterHasAudio ||
              _filterPriority != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد نتائج تطابق الفلتر',
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _limitTime = 'all';
                        _filterHasImages = false;
                        _filterHasAudio = false;
                        _filterPriority = null;
                        _customDateRange = null;
                      });
                    },
                    child: const Text('إلغاء التصفية'),
                  ),
                ],
              ),
            );
          }
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_sweep_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'سلة الملاحظات فارغة',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final isSelected = _selectedItemIds.contains(note.id);
            return TrashItemCard(
              item: note,
              isSelected: isSelected,
              isSelectionMode: _isSelectionMode,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(note.id);
                }
              },
              onLongPress: () => _enterSelectionMode(note.id),
            );
          },
        );
      },
    );
  }
}
