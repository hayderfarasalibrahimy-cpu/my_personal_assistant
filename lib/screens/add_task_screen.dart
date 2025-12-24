import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import 'package:gal/gal.dart';
import 'dart:io';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/full_screen_image.dart';
import '../services/file_service.dart';
import '../services/sound_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_service.dart';
import '../widgets/smart_text_field.dart';
import '../services/gemini_service.dart';
import '../services/explanation_service.dart';
import '../utils/app_snackbar.dart';
import '../widgets/glass_widgets.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;
  final bool isHidden;

  const AddTaskScreen({super.key, this.task, this.isHidden = false});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late SmartTextEditingController _descriptionController;
  DateTime? _dueDate;
  DateTime? _reminderTime; // وقت التذكير
  bool _enableReminder = false;
  String _repeatType = 'none'; // none, daily, weekly, custom
  List<int> _repeatDays = const []; // 1..7 (Mon..Sun)
  TaskPriority _priority = TaskPriority.medium;
  String _category = 'عام';
  final List<String> _audioPaths = [];
  final List<String> _imagePaths = [];
  final Set<String> _selectedImages = {};
  bool _isDownloading = false;
  final FileService _fileService = FileService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isReorganizing = false;
  bool _isSuggestingDetails = false;
  bool _isSummarizing = false;
  final List<String> _descriptionHistory = [];

  bool get _isAiWorking =>
      _isReorganizing || _isSuggestingDetails || _isSummarizing;

  final List<String> _categories = [
    'عام',
    'عمل',
    'شخصي',
    'دراسة',
    'صحة',
    'تسوق',
    'كلية',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = SmartTextEditingController(
      text: widget.task?.description ?? '',
      enableSpellCheck: false, // تعطيل التدقيق الإملائي
    );
    _dueDate = widget.task?.dueDate;
    _reminderTime = widget.task?.reminderTime;
    _enableReminder = widget.task?.reminderTime != null;
    _repeatType = widget.task?.repeatType ?? 'none';
    _repeatDays = widget.task?.repeatDays ?? const [];

    // إزالة weekdays من الواجهة: حافظ على المهام القديمة بتحويلها إلى custom
    if (_repeatType == 'weekdays') {
      _repeatType = 'custom';
      _repeatDays = const [1, 2, 3, 4, 5];
    }

    _priority = widget.task?.priority ?? TaskPriority.medium;
    _category = widget.task?.category ?? 'عام';
    if (widget.task?.audioPaths != null) {
      _audioPaths.addAll(widget.task!.audioPaths);
    }
    if (widget.task?.imagePaths != null) {
      _imagePaths.addAll(widget.task!.imagePaths);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'),
    );

    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _dueDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          // تفعيل التذكير تلقائياً عند اختيار تاريخ استحقاق
          _enableReminder = true;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: const Text('مسح مستند ضوئي'),
              onTap: () {
                Navigator.pop(context);
                _scanDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
        if (pickedFiles.isNotEmpty) {
          setState(() {
            _imagePaths.addAll(pickedFiles.map((file) => file.path));
          });
        }
      } else {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 80, // تقليل الجودة قليلاً لتوفير المساحة
          maxWidth: 1024, // تحديد عرض أقصى للصورة
        );
        if (pickedFile != null) {
          setState(() {
            _imagePaths.add(pickedFile.path);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> _scanDocument() async {
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          isGalleryImport: false,
          pageLimit: 5,
        ),
      );

      final result = await scanner.scanDocument();

      if (result.images.isNotEmpty) {
        setState(() {
          _imagePaths.addAll(result.images);
        });
      }
    } catch (e) {
      debugPrint('Error scanning document: $e');
      if (mounted) {
        String errorMessage = 'حدث خطأ أثناء المسح الضوئي';
        if (e.toString().contains('Operation cancelled')) {
          errorMessage = 'تم إلغاء عملية المسح';
        }
        AppSnackBar.error(context, errorMessage);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      final path = _imagePaths[index];
      _imagePaths.removeAt(index);
      _selectedImages.remove(path);
    });
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedImages.contains(path)) {
        _selectedImages.remove(path);
      } else {
        _selectedImages.add(path);
      }
    });
  }

  void _selectAllImages() {
    setState(() {
      if (_selectedImages.length == _imagePaths.length) {
        _selectedImages.clear();
      } else {
        _selectedImages.addAll(_imagePaths);
      }
    });
  }

  Future<void> _saveSelectedImages() async {
    if (_selectedImages.isEmpty) {
      AppSnackBar.warning(context, 'الرجاء تحديد صور لتنزيلها');
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      int successCount = 0;
      for (String path in _selectedImages) {
        try {
          await Gal.putImage(path);
          successCount++;
        } catch (e) {
          debugPrint('Failed to save image $path: $e');
        }
      }

      if (mounted) {
        AppSnackBar.success(
          context,
          'تم حفظ $successCount من ${_selectedImages.length} صورة في المعرض',
        );
        setState(() {
          _selectedImages.clear(); // Clear selection after download
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'فشل حفظ الصور';
        if (e is GalException) {
          errorMessage = 'فشل الوصول للمعرض: ${e.type}';
        }
        AppSnackBar.error(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      // حفظ الملفات الصوتية
      final List<String> savedAudioPaths = [];
      for (String audioPath in _audioPaths) {
        try {
          final mediaDir = await _fileService.getMediaPath();
          if (!audioPath.startsWith(mediaDir)) {
            final savedPath = await _fileService.saveFile(audioPath, 'audio');
            savedAudioPaths.add(savedPath);
          } else {
            savedAudioPaths.add(audioPath);
          }
        } catch (e) {
          debugPrint('Error saving audio: $e');
        }
      }

      // حفظ الصور
      final List<String> savedImagePaths = [];
      for (String imagePath in _imagePaths) {
        try {
          final mediaDir = await _fileService.getMediaPath();
          if (!imagePath.startsWith(mediaDir)) {
            final savedPath = await _fileService.saveFile(imagePath, 'images');
            savedImagePaths.add(savedPath);
          } else {
            savedImagePaths.add(imagePath);
          }
        } catch (e) {
          debugPrint('Error saving image: $e');
        }
      }

      if (!mounted) return;
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);

      if (widget.task == null) {
        // إضافة مهمة جديدة
        final newTask = Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          description: _descriptionController.text,
          dueDate: _dueDate,
          reminderTime: _enableReminder ? _dueDate : null,
          priority: _priority,
          category: _category,
          audioPaths: savedAudioPaths,
          imagePaths: savedImagePaths,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          repeatType: _repeatType,
          repeatDays: _repeatDays,
          isHidden: widget.isHidden,
          status: widget.isHidden ? TaskStatus.pending : TaskStatus.pending,
        );
        await taskProvider.addTask(newTask);

        // جدولة تذكير إذا كان هناك تاريخ استحقاق
        if (_dueDate != null && _enableReminder) {
          try {
            _reminderTime = _dueDate;
            // التحقق من أن الوقت في المستقبل أو مكرر
            if (_reminderTime!.isAfter(DateTime.now()) ||
                _repeatType != 'none') {
              final next = newTask.nextOccurrence;
              if (next != null && next.isAfter(DateTime.now())) {
                await AlarmService().scheduleAlarm(
                  scheduledTime: next,
                  title: newTask.title,
                  body: newTask.description.isNotEmpty
                      ? newTask.description
                      : 'حان وقت هذه المهمة!',
                  taskId: newTask.id,
                  repeatType: _repeatType,
                  repeatDays: _repeatDays,
                );
              }

              debugPrint('تم جدولة التذكير بنجاح للمهمة: ${newTask.title}');
            }
          } catch (e) {
            debugPrint('خطأ في جدولة التذكير: $e');
          }
        }
      } else {
        // تعديل مهمة موجودة
        final updatedTask = widget.task!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null && widget.task!.dueDate != null,
          reminderTime: _enableReminder ? _dueDate : null,
          clearReminderTime:
              (!_enableReminder || _dueDate == null) &&
              widget.task!.reminderTime != null,
          priority: _priority,
          category: _category,
          audioPaths: savedAudioPaths,
          imagePaths: savedImagePaths,
          repeatType: _repeatType,
          repeatDays: _repeatDays,
        );
        await taskProvider.updateTask(updatedTask);

        // تحديث تذكير إذا كان هناك تاريخ استحقاق
        if (_dueDate != null && _enableReminder) {
          try {
            _reminderTime = _dueDate;
            // التحقق من أن الوقت في المستقبل أو مكرر
            if (_reminderTime!.isAfter(DateTime.now()) ||
                _repeatType != 'none') {
              // إلغاء المنبه والإشعار القديم
              await NotificationService().cancelTaskNotifications(
                updatedTask.id,
              );
              AlarmService().cancelScheduledAlarm();

              // جدولة المنبه الجديد الموحد
              final next = updatedTask.nextOccurrence;
              if (next != null && next.isAfter(DateTime.now())) {
                await AlarmService().scheduleAlarm(
                  scheduledTime: next,
                  title: updatedTask.title,
                  body: updatedTask.description.isNotEmpty
                      ? updatedTask.description
                      : 'حان وقت هذه المهمة!',
                  taskId: updatedTask.id,
                  repeatType: _repeatType,
                  repeatDays: _repeatDays,
                );
              }

              debugPrint('تم تحديث التذكير بنجاح للمهمة: ${updatedTask.title}');
            }
          } catch (e) {
            debugPrint('خطأ في جدولة التذكير: $e');
          }
        } else {
          // إلغاء التذكير إذا تم تعطيله أو إلغاء التاريخ
          AlarmService().cancelScheduledAlarm();
        }
      }

      SoundService.playSuccess();
      if (!mounted) return;

      // إشعار نجاح الحفظ
      final message = widget.task == null
          ? 'تم إضافة المهمة بنجاح ✓'
          : 'تم تحديث المهمة بنجاح ✓';
      AppSnackBar.success(context, message, playSound: false);

      Navigator.pop(context);
    }
  }

  Future<void> _reorganizeDescription() async {
    if (_descriptionController.text.isEmpty) return;

    ExplanationService.showExplanationDialog(
      context: context,
      featureKey: 'reorganize_task',
      title: 'إعادة تنظيم الوصف بالذكاء الاصطناعي',
      explanation:
          'سأقوم بإعادة ترتيب فقرات وصف المهمة وتنسيقها بشكل أفضل لتكون واضحة وسهلة القراءة.',
      onProceed: () async {
        setState(() => _isReorganizing = true);
        try {
          final currentText = _descriptionController.text;
          final reorganized = await GeminiService.reorganizeContent(
            currentText,
          );
          if (reorganized.isNotEmpty) {
            setState(() {
              _descriptionHistory.add(currentText);
              _descriptionController.text = reorganized;
            });
          }
          if (mounted) {
            AppSnackBar.success(context, 'تم إعادة تنظيم الوصف بنجاح');
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.error(context, e.toString());
          }
        } finally {
          if (mounted) setState(() => _isReorganizing = false);
        }
      },
    );
  }

  Future<void> _suggestDetails() async {
    if (_titleController.text.isEmpty) {
      AppSnackBar.warning(context, 'الرجاء إدخال عنوان أولاً');
      return;
    }

    ExplanationService.showExplanationDialog(
      context: context,
      featureKey: 'suggest_task_details',
      title: 'اقتراح تفاصيل المهمة',
      explanation:
          'سأقوم بتحليل العنوان والوصف لاقتراح الأولوية المناسبة وتلخيص المهمة لك بشكل أذكى.',
      onProceed: () async {
        setState(() => _isSuggestingDetails = true);
        try {
          final details = await GeminiService.suggestTaskDetails(
            _titleController.text,
            _descriptionController.text,
          );

          if (mounted) {
            final priorityStr = details['priority'] ?? 'medium';
            TaskPriority newPriority = TaskPriority.medium;
            if (priorityStr == 'high') newPriority = TaskPriority.high;
            if (priorityStr == 'critical') newPriority = TaskPriority.critical;
            if (priorityStr == 'low') newPriority = TaskPriority.low;

            setState(() {
              _priority = newPriority;
            });

            AppSnackBar.success(context, 'تم تحديث تفاصيل المهمة ذكياً');
          }
          if (mounted) {
            AppSnackBar.success(context, 'تم تحسين تفاصيل المهمة');
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.error(context, 'فشل تحسين البيانات: $e');
          }
          debugPrint('Error suggesting task details: $e');
        } finally {
          if (mounted) setState(() => _isSuggestingDetails = false);
        }
      },
    );
  }

  Future<void> _summarizeDescription() async {
    if (_descriptionController.text.isEmpty) return;

    ExplanationService.showExplanationDialog(
      context: context,
      featureKey: 'summarize_task',
      title: 'تلخيص الوصف بالذكاء الاصطناعي',
      explanation:
          'سأقوم بتحليل الوصف المكتوب وتلخيصه في نقاط مختصرة ليسهل عليك قراءتها.',
      onProceed: () async {
        setState(() => _isSummarizing = true);
        try {
          final currentText = _descriptionController.text;
          final summary = await GeminiService.summarizeNote(currentText);
          if (summary.isNotEmpty) {
            setState(() {
              _descriptionHistory.add(currentText);
              _descriptionController.text = summary;
            });
          }
          if (mounted) {
            AppSnackBar.success(context, 'تم تلخيص الوصف بنجاح');
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.error(context, e.toString());
          }
        } finally {
          if (mounted) setState(() => _isSummarizing = false);
        }
      },
    );
  }

  void _undoAiEdit() {
    if (_descriptionHistory.isNotEmpty) {
      setState(() {
        _descriptionController.text = _descriptionHistory.removeLast();
      });
      AppSnackBar.info(context, 'تم استعادة النسخة السابقة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.task != null;

    return Stack(
      children: [
        SelectionArea(
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                isEditing ? 'تعديل المهمة' : 'مهمة جديدة',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                if (_descriptionController.text.isNotEmpty &&
                    _descriptionHistory.isNotEmpty)
                  Tooltip(
                    message: 'استعادة التعديل السابق للذكاء الاصطناعي',
                    child: IconButton(
                      icon: const Icon(Icons.undo, size: 20),
                      onPressed: _undoAiEdit,
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.blue,
                    size: 20,
                  ),
                  tooltip: 'أدوات الذكاء الاصطناعي',
                  onSelected: (value) {
                    if (value == 'reorganize') _reorganizeDescription();
                    if (value == 'suggest') _suggestDetails();
                    if (value == 'summarize') _summarizeDescription();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'summarize',
                      child: Row(
                        children: [
                          _isSummarizing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.summarize, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            'تلخيص الوصف',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reorganize',
                      child: Row(
                        children: [
                          _isReorganizing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.format_align_right, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            'تنظيم الوصف',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'suggest',
                      child: Row(
                        children: [
                          _isSuggestingDetails
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.assistant, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            'اقتراح الأولوية',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    blur: 15,
                    opacity: 0.1,
                    color: Colors.green.shade900,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.white,
                      ),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: _saveTask,
                      tooltip: 'حفظ',
                    ),
                  ),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // عنوان المهمة
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'عنوان المهمة',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title, size: 20),
                      suffixIcon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy, size: 14),
                            onPressed: () {
                              if (_titleController.text.isNotEmpty) {
                                Clipboard.setData(
                                  ClipboardData(text: _titleController.text),
                                );
                                AppSnackBar.info(context, 'تم نسخ العنوان');
                              }
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.paste, size: 14),
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                'text/plain',
                              );
                              if (data?.text != null) {
                                setState(() {
                                  _titleController.text = data!.text!;
                                });
                              }
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 14,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('تأكيد المسح'),
                                  content: const Text(
                                    'هل أنت متأكد من مسح العنوان بالكامل؟',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _titleController.clear();
                                        });
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'مسح',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال عنوان المهمة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // وصف المهمة - موسع ومتعدد الأسطر مع ترقيم تلقائي
                  SmartTextField(
                    controller: _descriptionController,
                    labelText: 'الوصف (اختياري)',
                    hintText: 'أضف تفاصيل المهمة هنا...',
                    minLines: 2,
                    maxLines: 5,
                    enableSpellCheck: false, // تعطيل التدقيق الإملائي
                    enableAutoNumbering: true,
                    showWordCount: true,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'أضف تفاصيل المهمة هنا...',
                      hintStyle: const TextStyle(fontSize: 12),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 30),
                        child: Icon(Icons.description, size: 20),
                      ),
                      suffixIcon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy, size: 14),
                            onPressed: () {
                              if (_descriptionController.text.isNotEmpty) {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: _descriptionController.text,
                                  ),
                                );
                                AppSnackBar.info(context, 'تم نسخ الوصف');
                              }
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.paste, size: 14),
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                'text/plain',
                              );
                              if (data?.text != null) {
                                setState(() {
                                  _descriptionController.text = data!.text!;
                                });
                              }
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 14,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('تأكيد المسح'),
                                  content: const Text(
                                    'هل أنت متأكد من مسح الوصف بالكامل؟',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _descriptionController.clear();
                                        });
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'مسح',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // التصنيف
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: InputDecoration(
                      labelText: 'التصنيف',
                      labelStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category, size: 20),
                    ),
                    style: const TextStyle(fontSize: 12),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _category = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // الأولوية
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الأولوية',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildPriorityChip(
                            'منخفضة',
                            TaskPriority.low,
                            Colors.green,
                          ),
                          const SizedBox(width: 6),
                          _buildPriorityChip(
                            'متوسطة',
                            TaskPriority.medium,
                            Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          _buildPriorityChip(
                            'عالية',
                            TaskPriority.high,
                            Colors.red,
                          ),
                          const SizedBox(width: 6),
                          _buildPriorityChip(
                            'حرجة',
                            TaskPriority.critical,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // عرض تواريخ الإنشاء والتعديل
                  if (isEditing) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'أُضيفت: ${DateFormat('dd/MM/yyyy hh:mm a', 'en').format(widget.task!.createdAt).replaceAll('AM', 'ص').replaceAll('PM', 'م')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.edit_calendar,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'آخر تعديل: ${DateFormat('dd/MM/yyyy hh:mm a', 'en').format(widget.task!.updatedAt).replaceAll('AM', 'ص').replaceAll('PM', 'م')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // تاريخ الاستحقاق
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    title: Center(
                      child: Text(
                        _dueDate == null
                            ? 'تحديد تاريخ الاستحقاق'
                            : DateFormat('yyyy/MM/dd - hh:mm a', 'en')
                                  .format(_dueDate!)
                                  .replaceAll('AM', 'ص')
                                  .replaceAll('PM', 'م'),
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    trailing: _dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _dueDate = null;
                                _enableReminder = false;
                              });
                            },
                          )
                        : null,
                    onTap: _selectDate,
                  ),

                  // تفعيل التذكير
                  if (_dueDate != null)
                    CheckboxListTile(
                      value: _enableReminder,
                      onChanged: (value) {
                        setState(() {
                          _enableReminder = value ?? false;
                        });
                      },
                      title: const Text(
                        'تذكيري في هذا الموعد',
                        style: TextStyle(fontSize: 12),
                      ),
                      subtitle: const Text(
                        'إرسال إشعار تذكير عند حلول الموعد',
                        style: TextStyle(fontSize: 11),
                      ),
                      secondary: Icon(
                        Icons.notifications_active,
                        color: _enableReminder
                            ? theme.primaryColor
                            : Colors.grey,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.dividerColor),
                      ),
                    ),

                  // خيارات التكرار
                  if (_dueDate != null && _enableReminder) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.repeat,
                                color: theme.primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'تكرار التذكير',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildRepeatChip(
                                'بدون',
                                'none',
                                Icons.do_not_disturb_alt,
                              ),
                              _buildRepeatChip('يومياً', 'daily', Icons.today),
                              _buildRepeatChip(
                                'أسبوعياً',
                                'weekly',
                                Icons.date_range,
                              ),
                              _buildRepeatChip('مخصص', 'custom', Icons.tune),
                            ],
                          ),
                          if (_repeatType == 'custom') ...[
                            const SizedBox(height: 12),
                            _buildRepeatDaysSelector(),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // مسجل الصوت
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تسجيل صوتي',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AudioRecorderWidget(
                        existingAudioPaths: _audioPaths,
                        onRecordingsChanged: (paths) {
                          setState(() {
                            _audioPaths.clear();
                            _audioPaths.addAll(paths);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // الصور
                  // الصور
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'الصور',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          if (_imagePaths.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            if (_isDownloading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              IconButton(
                                onPressed: _selectedImages.isEmpty
                                    ? null
                                    : _saveSelectedImages,
                                icon: const Icon(Icons.download_rounded),
                                iconSize: 20,
                                tooltip: 'تنزيل المحدد',
                                visualDensity: VisualDensity.compact,
                              ),
                            IconButton(
                              onPressed: _selectAllImages,
                              icon: Icon(
                                _selectedImages.length == _imagePaths.length
                                    ? Icons.deselect
                                    : Icons.select_all,
                              ),
                              iconSize: 20,
                              tooltip:
                                  _selectedImages.length == _imagePaths.length
                                  ? 'إلغاء التحديد'
                                  : 'تحديد الكل',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(
                              Icons.add_photo_alternate,
                              size: 18,
                            ),
                            label: const Text(
                              'إضافة صور',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_imagePaths.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imagePaths.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FullScreenImage(
                                                  imagePaths: _imagePaths,
                                                  initialIndex: index,
                                                ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          File(_imagePaths[index]),
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    // Selection Circle
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: GestureDetector(
                                        onTap: () => _toggleSelection(
                                          _imagePaths[index],
                                        ),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                _selectedImages.contains(
                                                  _imagePaths[index],
                                                )
                                                ? theme.primaryColor
                                                : Colors.black.withValues(
                                                    alpha: 0.3,
                                                  ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child:
                                              _selectedImages.contains(
                                                _imagePaths[index],
                                              )
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                    // Delete Button
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 8,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade900, Colors.green.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saveTask,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      width: double.infinity,
                      child: Text(
                        isEditing ? 'حفظ التعديلات' : 'إضافة المهمة',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isAiWorking)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.blue,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey.shade900
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'الذكاء الاصطناعي يعمل الآن...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              fontSize: 13,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriorityChip(String label, TaskPriority priority, Color color) {
    final isSelected = _priority == priority;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _priority = priority;
          });
        },
        selectedColor: color.withValues(alpha: 0.3),
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(
          color: isSelected ? color : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildRepeatChip(String label, String type, IconData icon) {
    final isSelected = _repeatType == type;
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    final onSurface = theme.colorScheme.onSurface;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? onPrimary : primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _repeatType = selected ? type : 'none';
          if (_repeatType == 'custom' && _repeatDays.isEmpty) {
            _repeatDays = const [1, 2, 3, 4, 5, 6, 7];
          }
        });
      },
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      selectedColor: primary,
      backgroundColor: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surfaceContainerLow,
      side: BorderSide(
        color: isSelected
            ? primary
            : (isDark
                  ? theme.colorScheme.outlineVariant
                  : theme.colorScheme.outline),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? onPrimary : onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildRepeatDaysSelector() {
    final theme = Theme.of(context);
    final days = const <int, String>{
      7: 'الأحد',
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
    };

    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: days.entries.map((e) {
          final selected = _repeatDays.contains(e.key);
          return FilterChip(
            label: Text(
              e.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? onPrimary : onSurface,
              ),
            ),
            selected: selected,
            onSelected: (v) {
              setState(() {
                final next = [..._repeatDays];
                if (v) {
                  if (!next.contains(e.key)) next.add(e.key);
                } else {
                  next.remove(e.key);
                }
                next.sort();
                _repeatDays = next;
              });
            },
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            backgroundColor: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerLow,
            selectedColor: primary,
            side: BorderSide(
              color: selected
                  ? primary
                  : (isDark
                        ? theme.colorScheme.outlineVariant
                        : theme.colorScheme.outline),
              width: 1,
            ),
          );
        }).toList(),
      ),
    );
  }
}
