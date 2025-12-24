import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:gal/gal.dart';
import '../services/file_service.dart';
import '../services/gemini_service.dart';
import '../services/explanation_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/full_screen_image.dart';
import '../widgets/smart_text_field.dart';
import '../utils/app_snackbar.dart';

class AddNoteScreen extends StatefulWidget {
  final Note? note;
  final bool isHidden;

  const AddNoteScreen({super.key, this.note, this.isHidden = false});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late SmartTextEditingController _contentController;
  bool _isPinned = false;
  Color _color = Colors.white;
  final List<String> _audioPaths = [];

  List<String> _imagePaths = [];
  final Set<String> _selectedImages = {};
  bool _isDownloading = false;
  final FileService _fileService = FileService();

  // لخدمة الذكاء الاصطناعي
  final List<String> _contentHistory = [];
  bool _isSummarizing = false;
  bool _isSuggestingFolder = false;
  bool _isReorganizing = false;

  bool get _isAiWorking =>
      _isSummarizing || _isSuggestingFolder || _isReorganizing;

  final List<Color> _noteColors = [
    Colors.white,
    Colors.red.shade100,
    Colors.orange.shade100,
    Colors.yellow.shade100,
    Colors.green.shade100,
    Colors.blue.shade100,
    Colors.purple.shade100,
    Colors.pink.shade100,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = SmartTextEditingController(
      text: widget.note?.content ?? '',
      enableSpellCheck: false, // تعطيل التدقيق الإملائي
    );
    _isPinned = widget.note?.isPinned ?? false;
    _color = widget.note?.color ?? Colors.white;
    if (widget.note?.audioPaths != null) {
      _audioPaths.addAll(widget.note!.audioPaths);
    }
    _imagePaths = List.from(widget.note?.imagePaths ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
    final ImagePicker picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty) {
          setState(() {
            _imagePaths.addAll(images.map((img) => img.path));
          });
        }
      } else {
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1024,
        );
        if (image != null) {
          setState(() {
            _imagePaths.add(image.path);
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

  Future<void> _saveNote() async {
    if (_formKey.currentState!.validate()) {
      // 1. معالجة وحفظ ملفات الوسائط
      List<String> savedAudioPaths = [];
      List<String> savedImagePaths = [];

      try {
        final mediaDir = await _fileService.getMediaPath();

        // حفظ الصوت إذا كان جديداً
        for (String path in _audioPaths) {
          if (!path.startsWith(mediaDir)) {
            final newPath = await _fileService.saveFile(path, 'audio');
            savedAudioPaths.add(newPath);
          } else {
            savedAudioPaths.add(path);
          }
        }

        // حفظ الصور الجديدة
        for (String path in _imagePaths) {
          if (!path.startsWith(mediaDir)) {
            final newPath = await _fileService.saveFile(path, 'image');
            savedImagePaths.add(newPath);
          } else {
            savedImagePaths.add(path);
          }
        }
      } catch (e) {
        debugPrint('Error saving media: $e');
        if (mounted) {
          AppSnackBar.error(context, 'حدث خطأ أثناء حفظ الوسائط: $e');
        }
        return; // توقف إذا فشل حفظ الوسائط
      }

      if (!mounted) return;
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);

      if (widget.note == null) {
        // إضافة ملاحظة جديدة
        final newNote = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          content: _contentController.text,
          isPinned: _isPinned,
          color: _color,
          audioPaths: savedAudioPaths,
          imagePaths: savedImagePaths,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          folderId: noteProvider.currentFolderId,
          isHidden: widget.isHidden,
        );
        noteProvider.addNote(newNote);
      } else {
        // تعديل ملاحظة موجودة
        final updatedNote = widget.note!.copyWith(
          title: _titleController.text,
          content: _contentController.text,
          isPinned: _isPinned,
          color: _color,
          audioPaths: savedAudioPaths,
          imagePaths: savedImagePaths,
          updatedAt: DateTime.now(),
        );
        noteProvider.updateNote(updatedNote);
      }

      // إشعار نجاح الحفظ
      final message = widget.note == null
          ? 'تم إضافة الملاحظة بنجاح ✓'
          : 'تم تحديث الملاحظة بنجاح ✓';
      AppSnackBar.success(context, message);

      Navigator.pop(context);
    }
  }

  Future<void> _summarizeContent() async {
    if (_contentController.text.isEmpty) return;

    ExplanationService.showExplanationDialog(
      context: context,
      featureKey: 'summarize_note',
      title: 'تلخيص الملاحظة بالذكاء الاصطناعي',
      explanation:
          'سأقوم بقراءة محتوى ملاحظتك واستخلاص أهم النقاط في شكل ملخص قصير ليسهل عليك مراجعتها لاحقاً. يمكنك دائماً استعادة النص الأصلي.',
      onProceed: () async {
        setState(() => _isSummarizing = true);
        try {
          final currentText = _contentController.text;
          final summary = await GeminiService.summarizeNote(currentText);
          if (summary.isNotEmpty) {
            setState(() {
              _contentHistory.add(currentText);
              _contentController.text = summary;
            });
          }
          if (mounted) {
            AppSnackBar.success(context, 'تم تلخيص الملاحظة بنجاح');
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
    if (_contentHistory.isNotEmpty) {
      setState(() {
        _contentController.text = _contentHistory.removeLast();
      });
      AppSnackBar.info(context, 'تم استعادة النسخة السابقة');
    }
  }

  Future<void> _suggestFolder() async {
    if (_contentController.text.isEmpty) return;

    ExplanationService.showExplanationDialog(
      context: context,
      featureKey: 'suggest_folder',
      title: 'اقتراح مجلد ذكي',
      explanation:
          'سأقوم بتحليل عنوان ومحتوى الملاحظة واقتراح أنسب مجلد لها من بين مجلداتك الحالية لتنظيم ملاحظاتك بشكل أفضل.',
      onProceed: () async {
        setState(() => _isSuggestingFolder = true);
        try {
          final noteProvider = Provider.of<NoteProvider>(
            context,
            listen: false,
          );
          final folders = noteProvider.folders;
          final folderNames = folders.map((f) => f.name).toList();

          if (folderNames.isEmpty) {
            if (mounted) {
              AppSnackBar.info(context, 'لا توجد مجلدات متاحة للاقتراح');
            }
            return;
          }

          final suggestedName = await GeminiService.suggestFolder(
            _contentController.text,
            folderNames,
          );

          final suggestedFolder = folders.firstWhere(
            (f) => f.name == suggestedName,
            orElse: () => folders.first,
          );

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                title: const Text(
                  'اقتراح المجلد',
                  style: TextStyle(fontSize: 16),
                ),
                content: Text(
                  'هل تريد نقل هذه الملاحظة إلى مجلد "$suggestedName"؟',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      noteProvider.setFolder(suggestedFolder);
                      Navigator.pop(context);
                      AppSnackBar.success(
                        context,
                        'تم نقل الملاحظة إلى $suggestedName',
                      );
                    },
                    child: const Text('نقل'),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.error(context, e.toString());
          }
          debugPrint('Error suggesting folder: $e');
        } finally {
          if (mounted) setState(() => _isSuggestingFolder = false);
        }
      },
    );
  }

  Future<void> _reorganizeContent() async {
    if (_contentController.text.isEmpty) return;

    ExplanationService.showExplanationDialog(
      context: context,
      featureKey: 'reorganize_note',
      title: 'إعادة تنظيم النص بالذكاء الاصطناعي',
      explanation:
          'سأقوم بإعادة ترتيب فقرات ملاحظتك وتصحيح الأخطاء اللغوية وتنسيقها بشكل احترافي مع الحفاظ على كافة المعلومات.',
      onProceed: () async {
        setState(() => _isReorganizing = true);
        try {
          final currentText = _contentController.text;
          final reorganized = await GeminiService.reorganizeContent(
            currentText,
          );
          if (reorganized.isNotEmpty) {
            setState(() {
              _contentHistory.add(currentText);
              _contentController.text = reorganized;
            });
          }
          if (mounted) {
            AppSnackBar.success(context, 'تم إعادة تنظيم النص بنجاح');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.note != null;

    return Stack(
      children: [
        SelectionArea(
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                isEditing ? 'تعديل الملاحظة' : 'ملاحظة جديدة',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                if (_contentController.text.isNotEmpty &&
                    _contentHistory.isNotEmpty)
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
                    if (value == 'summarize') _summarizeContent();
                    if (value == 'suggest') _suggestFolder();
                    if (value == 'reorganize') _reorganizeContent();
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
                            'تلخيص الملاحظة',
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
                            'إعادة تنظيم النص',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'suggest',
                      child: Row(
                        children: [
                          _isSuggestingFolder
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.folder_special, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            'اقتراح مجلد',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 20,
                  ),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPinned = !_isPinned;
                    });
                  },
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
                      onPressed: _saveNote,
                      tooltip: 'حفظ',
                    ),
                  ),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: [
                        // عنوان الملاحظة
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'العنوان',
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
                                        ClipboardData(
                                          text: _titleController.text,
                                        ),
                                      );
                                      AppSnackBar.info(
                                        context,
                                        'تم نسخ العنوان',
                                      );
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
                                            onPressed: () =>
                                                Navigator.pop(context),
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
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
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
                              return 'الرجاء إدخال عنوان الملاحظة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        const SizedBox(height: 8),

                        // محتوى الملاحظة مع ترقيم تلقائي
                        SmartTextField(
                          controller: _contentController,
                          labelText: 'المحتوى',
                          hintText: 'اكتب محتوى الملاحظة هنا...',
                          maxLines: 10,
                          enableSpellCheck: false, // تعطيل التدقيق الإملائي
                          enableAutoNumbering: true,
                          showWordCount: true,
                          decoration: InputDecoration(
                            labelText: 'المحتوى',
                            labelStyle: const TextStyle(fontSize: 12),
                            hintText: 'اكتب محتوى الملاحظة هنا...',
                            hintStyle: const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignLabelWithHint: true,
                            suffixIcon: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.copy, size: 14),
                                  onPressed: () {
                                    if (_contentController.text.isNotEmpty) {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: _contentController.text,
                                        ),
                                      );
                                      AppSnackBar.info(
                                        context,
                                        'تم نسخ المحتوى',
                                      );
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
                                        _contentController.text = data!.text!;
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
                                          'هل أنت متأكد من مسح المحتوى بالكامل؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('إلغاء'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _contentController.clear();
                                              });
                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'مسح',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
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
                              return 'الرجاء إدخال محتوى الملاحظة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // عرض تواريخ الإنشاء والتعديل
                        if (isEditing) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _color.withValues(alpha: 0.1),
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
                                      'أُنشئت: ${DateFormat('dd/MM/yyyy hh:mm a', 'en').format(widget.note!.createdAt).replaceAll('AM', 'ص').replaceAll('PM', 'م')}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
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
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'آخر تعديل: ${DateFormat('dd/MM/yyyy hh:mm a', 'en').format(widget.note!.updatedAt).replaceAll('AM', 'ص').replaceAll('PM', 'م')}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // مسجل الصوت
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تسجيل صوتي',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 12,
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
                              onTranscribe: (text) {
                                if (mounted) {
                                  setState(() {
                                    _contentController.text =
                                        '${_contentController.text}\n\n[نص مسجل]:\n$text';
                                  });
                                  AppSnackBar.success(
                                    context,
                                    'تم تحويل التسجيل إلى نص',
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // الصور
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'الصور المرفقة',
                                  style: theme.textTheme.titleMedium?.copyWith(
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
                                      _selectedImages.length ==
                                              _imagePaths.length
                                          ? Icons.deselect
                                          : Icons.select_all,
                                    ),
                                    iconSize: 20,
                                    tooltip:
                                        _selectedImages.length ==
                                            _imagePaths.length
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
                                height: 100,
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_imagePaths[index]),
                                                height: 100,
                                                width: 100,
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
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () => _removeImage(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 14,
                                                  color: Colors.white,
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

                  // اختيار اللون
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _noteColors.length,
                      itemBuilder: (context, index) {
                        final color = _noteColors[index];
                        return Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: GestureDetector(
                            onTap: () => setState(() => _color = color),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _color == color
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                  width: _color == color ? 2 : 1,
                                ),
                              ),
                              child: _color == color
                                  ? const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Colors.blue,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // زر الحفظ السفلي (اختياري، مكرر للسهولة)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade700,
                                Colors.blue.shade900,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _saveNote,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                width: double.infinity,
                                child: Text(
                                  isEditing
                                      ? 'حفظ التعديلات'
                                      : 'إضافة الملاحظة',
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
                      ],
                    ),
                  ),
                ],
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
}
