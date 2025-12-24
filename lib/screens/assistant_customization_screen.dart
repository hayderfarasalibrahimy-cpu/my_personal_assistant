import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/assistant_customization_service.dart';
import '../services/avatar_service.dart';
import '../services/gemini_service.dart';
import '../widgets/assistant_avatar.dart';
import '../utils/app_snackbar.dart';

/// شاشة تخصيص المساعد الشخصي الكاملة
class AssistantCustomizationScreen extends StatefulWidget {
  const AssistantCustomizationScreen({super.key});

  @override
  State<AssistantCustomizationScreen> createState() =>
      _AssistantCustomizationScreenState();
}

class _AssistantCustomizationScreenState
    extends State<AssistantCustomizationScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedPersonality = 'default';
  int _selectedAvatarIndex = 0;
  bool _isCustomAvatar = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await AssistantCustomizationService.loadSettings();
    await AvatarService.loadSettings();

    setState(() {
      _nameController.text = AssistantCustomizationService.assistantName;
      _selectedPersonality = AssistantCustomizationService.assistantPersonality;
      _selectedAvatarIndex = AvatarService.avatarIndex;
      _isCustomAvatar = AvatarService.avatarType == 'custom';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _generateRandomName() {
    setState(() {
      _nameController.text = AssistantCustomizationService.getRandomIraqiName();
    });
  }

  Future<void> _pickCustomImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        await AvatarService.setCustomAvatar(file);

        setState(() {
          _isCustomAvatar = true;
        });

        if (mounted) {
          AppSnackBar.success(context, 'تم تحديث الصورة بنجاح ✓');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'خطأ في تحميل الصورة: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    await AssistantCustomizationService.setAssistantName(
      _nameController.text.trim(),
    );
    await AssistantCustomizationService.setAssistantPersonality(
      _selectedPersonality,
    );

    // إعادة تهيئة الذكاء الاصطناعي بالإعدادات الجديدة
    await GeminiService.initialize();

    if (mounted) {
      AppSnackBar.success(context, 'تم حفظ إعدادات المساعد ✓');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تخصيص المساعد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'حفظ',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ====== قسم الأفاتار ======
          _buildAvatarSection(),
          const SizedBox(height: 24),

          // ====== قسم الاسم ======
          _buildNameSection(),
          const SizedBox(height: 16),

          // ====== قسم الشخصية ======
          _buildPersonalitySection(),
          const SizedBox(height: 24),

          // ====== أزرار الحفظ ======
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '🎨 شكل المساعد',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isCustomAvatar)
                  TextButton.icon(
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('افتراضي'),
                    onPressed: () async {
                      await AvatarService.setDefaultAvatar(
                        _selectedAvatarIndex,
                      );
                      setState(() => _isCustomAvatar = false);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'اختر أفاتار للمساعد أو ارفع صورة من جهازك',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // الأفاتار الحالي في المنتصف
            Center(
              child: Stack(
                children: [
                  AssistantAvatar(size: 100, animated: true, showBorder: true),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _pickCustomImage,
                        tooltip: 'رفع صورة',
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // شبكة الأفاتار الافتراضية
            Text(
              'الأفاتار الافتراضية:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            AvatarSelector(
              selectedIndex: _isCustomAvatar ? null : _selectedAvatarIndex,
              onSelect: (index) async {
                await AvatarService.setDefaultAvatar(index);
                setState(() {
                  _selectedAvatarIndex = index;
                  _isCustomAvatar = false;
                });
              },
            ),
            const SizedBox(height: 16),

            // زر رفع صورة مخصصة
            OutlinedButton.icon(
              onPressed: _pickCustomImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('رفع صورة من المعرض'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏷️ اسم المساعد',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'اختر اسماً لمساعدك الشخصي أو اتركه فارغاً للاسم الافتراضي',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'مثال: زيدون، ياسر',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.casino),
                  tooltip: 'اسم عشوائي عراقي',
                  onPressed: _generateRandomName,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎭 شخصية المساعد',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'اختر أسلوب تواصل المساعد معك',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AssistantCustomizationService.personalities.keys.map((
                key,
              ) {
                return _buildPersonalityChip(key);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalityChip(String key) {
    final isSelected = _selectedPersonality == key;
    final title = _getPersonalityTitle(key);

    return GestureDetector(
      onTap: () => setState(() => _selectedPersonality = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save),
          label: const Text('حفظ الإعدادات'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await AssistantCustomizationService.resetToDefaults();
            await AvatarService.resetToDefault();
            await _loadSettings();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة للافتراضي'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  String _getPersonalityTitle(String key) {
    switch (key) {
      case 'default':
        return '🤖 افتراضي';
      case 'formal':
        return '👔 رسمي';
      case 'friendly':
        return '😊 ودود';
      case 'wise':
        return '🧙 حكيم';
      case 'energetic':
        return '⚡ نشيط';
      default:
        return key;
    }
  }
}
