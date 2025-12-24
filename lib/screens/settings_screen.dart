import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_provider.dart';
import '../providers/task_provider.dart';
import '../providers/note_provider.dart';

import '../services/database_service.dart';
import '../services/backup_service.dart';
import '../services/sound_service.dart';
import '../services/background_service.dart';
import '../services/font_service.dart';
import '../services/api_key_service.dart';
import '../services/gemini_service.dart';
import '../services/user_service.dart';
import 'dart:io';

import '../utils/app_theme.dart';
import '../widgets/glass_widgets.dart';
import 'robot_settings_screen.dart';
import 'assistant_customization_screen.dart';
import 'notification_settings_screen.dart';
import 'ai_settings_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_snackbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // State variables
  bool _soundEnabled = SoundService.isSoundEnabled;
  bool _hapticEnabled = SoundService.isHapticEnabled;
  String _selectedClickSound = SoundService.selectedClickSound;
  String _selectedSuccessSound = SoundService.selectedSuccessSound;
  String _selectedDeleteSound = SoundService.selectedDeleteSound;
  String _backgroundType = BackgroundService.backgroundType;

  double _opacity = BackgroundService.opacity;
  String _selectedFont = FontService.selectedFont;
  final ImagePicker _picker = ImagePicker();

  // User details
  String _userName = '';
  String _userAvatar = 'avatar_1';

  // API Key state for UI display
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkApiKey();
  }

  Future<void> _loadUserData() async {
    final name = await UserService.getUserName();
    final avatar = await UserService.getUserAvatar();
    if (mounted) {
      setState(() {
        _userName = name;
        _userAvatar = avatar;
      });
    }
  }

  Future<void> _checkApiKey() async {
    final hasKey = await ApiKeyService.hasCustomApiKey();
    if (mounted) {
      setState(() {
        _hasApiKey = hasKey;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgWidget = BackgroundService.getBackgroundWidget(isDarkMode: isDark);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (bgWidget != null) Positioned.fill(child: bgWidget),
          CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text('الإعدادات'),
                centerTitle: false,
                actions: [_buildUserHeader(context, theme)],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),
                    // === Appearance Section ===
                    _SettingsSection(
                      title: 'المظهر والخطوط',
                      icon: Icons.palette_outlined,
                      color: Colors.purple,
                      children: [
                        _SettingsTile(
                          icon: Icons.dark_mode_outlined,
                          color: Colors.indigo,
                          title: 'نظام الألوان',
                          subtitle: 'اختر المظهر المفضل للتطبيق',
                          child: Consumer<ThemeProvider>(
                            builder: (context, themeProvider, _) => Row(
                              children: [
                                _ThemeOption(
                                  label: 'داكن',
                                  isSelected:
                                      themeProvider.currentTheme ==
                                      AppThemeMode.dark,
                                  onTap: () =>
                                      themeProvider.setTheme(AppThemeMode.dark),
                                  color: const Color(0xFF1E1E1E),
                                ),
                                const SizedBox(width: 8),
                                _ThemeOption(
                                  label: 'AMOLED',
                                  isSelected:
                                      themeProvider.currentTheme ==
                                      AppThemeMode.amoled,
                                  onTap: () => themeProvider.setTheme(
                                    AppThemeMode.amoled,
                                  ),
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.wallpaper_outlined,
                          color: Colors.deepPurple,
                          title: 'الخلفية',
                          subtitle: _getBackgroundName(),
                          onTap: () => _showBackgroundPicker(context),
                          trailing:
                              _backgroundType != BackgroundService.typeNone
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  tooltip: 'إزالة الخلفية',
                                  onPressed: () async {
                                    await BackgroundService.clearBackground();
                                    setState(() {
                                      _backgroundType =
                                          BackgroundService.typeNone;
                                    });
                                    if (mounted) {
                                      if (!context.mounted) return;
                                      AppSnackBar.success(
                                        context,
                                        'تمت إزالة الخلفية',
                                      );
                                    }
                                  },
                                )
                              : const Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                        if (_backgroundType != BackgroundService.typeNone) ...[
                          const SizedBox(height: 12),
                          _SettingsTile(
                            icon: Icons.opacity,
                            color: Colors.teal,
                            title: 'شفافية الخلفية',
                            subtitle: '${(_opacity * 100).toInt()}%',
                            child: Slider(
                              value: _opacity,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (value) async {
                                setState(() => _opacity = value);
                                await BackgroundService.setOpacity(value);
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.text_fields_rounded,
                          color: Colors.pink,
                          title: 'نوع الخط',
                          subtitle: FontService.availableFonts[_selectedFont],
                          onTap: _showFontPicker,
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // === Assistant Section ===
                    _SettingsSection(
                      title: 'المساعد الذكي',
                      icon: Icons.smart_toy_outlined,
                      color: Colors.blue,
                      children: [
                        _SettingsTile(
                          icon: Icons.face,
                          color: Colors.blueAccent,
                          title: 'تخصيص المساعد',
                          subtitle: 'الاسم، الشخصية، والأفاتار',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AssistantCustomizationScreen(),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.tune,
                          color: Colors.cyan,
                          title: 'إعدادات الروبوت',
                          subtitle: 'الحركة، التفاعل، والظهور',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: '/robot-settings',
                              ),
                              builder: (_) => const RobotSettingsScreen(),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.key,
                          color: Colors.amber,
                          title: 'مفتاح API',
                          subtitle: _hasApiKey ? 'مضبوط وتعمل' : 'غير مضبوط',
                          onTap: _showApiKeyDialog,
                          trailing: Icon(
                            _hasApiKey
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: _hasApiKey ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.settings_ethernet,
                          color: Colors.lightBlue,
                          title: 'إعدادات النماذج والمفاتيح',
                          subtitle: 'OpenRouter, Gemini, ترتيب الأولويات',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AiSettingsScreen(),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // === Notifications & Sound Section ===
                    _SettingsSection(
                      title: 'التنبيهات والصوت',
                      icon: Icons.notifications_outlined,
                      color: Colors.orange,
                      children: [
                        _SettingsTile(
                          icon: Icons.notifications_active_outlined,
                          color: Colors.deepOrange,
                          title: 'الإشعارات',
                          subtitle: 'تخصيص التنبيهات والمنبهات',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationSettingsScreen(),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.volume_up_outlined,
                          color: Colors.green,
                          title: 'أصوات التفاعل',
                          subtitle: 'تشغيل أصوات عند النقر والإجراءات',
                          trailing: Switch(
                            value: _soundEnabled,
                            onChanged: (value) async {
                              await SoundService.setSoundEnabled(value);
                              setState(() => _soundEnabled = value);
                            },
                          ),
                        ),
                        if (_soundEnabled) ...[
                          const SizedBox(height: 12),
                          _SettingsTile(
                            icon: Icons.ads_click,
                            color: Colors.lightGreen,
                            title: 'نغمة النقر',
                            subtitle: _getSoundName(_selectedClickSound),
                            onTap: () => _showSoundPicker('click'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _SettingsTile(
                            icon: Icons.check_circle_outline,
                            color: Colors.lightGreen,
                            title: 'نغمة النجاح',
                            subtitle: _getSoundName(_selectedSuccessSound),
                            onTap: () => _showSoundPicker('success'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _SettingsTile(
                            icon: Icons.delete_outline,
                            color: Colors.lightGreen,
                            title: 'نغمة الحذف',
                            subtitle: _getSoundName(_selectedDeleteSound),
                            onTap: () => _showSoundPicker('delete'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.vibration,
                          color: Colors.teal,
                          title: 'الاهتزاز',
                          subtitle: 'اهتزاز الجهاز عند التفاعل',
                          trailing: Switch(
                            value: _hapticEnabled,
                            onChanged: (value) async {
                              await SoundService.setHapticEnabled(value);
                              setState(() => _hapticEnabled = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // === Data & Storage Section ===
                    _SettingsSection(
                      title: 'البيانات والتخزين',
                      icon: Icons.storage_outlined,
                      color: Colors.red,
                      children: [
                        _SettingsTile(
                          icon: Icons.backup_outlined,
                          color: Colors.blueGrey,
                          title: 'النسخ الاحتياطي',
                          subtitle: 'تصدير واستيراد البيانات',
                          onTap: _showBackupOptions,
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.folder_delete_outlined,
                          color: Colors.redAccent,
                          title: 'مسح البيانات',
                          subtitle: 'حذف جميع المهام والملاحظات',
                          onTap: _showDeleteDataDialog,
                          trailing: const Icon(
                            Icons.delete_forever,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Footer
                    Center(
                      child: Text(
                        'مذكرة الحياة v1.4.2',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'تم التطوير بواسطة حيدر فراس',
                        style: TextStyle(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === Helper Methods ===

  String _getBackgroundName() {
    switch (_backgroundType) {
      case BackgroundService.typeAsset:
        return 'خلفية جاهزة';
      case BackgroundService.typeCustom:
        return 'صورة مخصصة';
      default:
        return 'بدون خلفية';
    }
  }

  String _getSoundName(String path) {
    if (path.contains('click1')) {
      return 'نقرات 1';
    }
    if (path.contains('click2')) {
      return 'نقرات 2';
    }
    if (path.contains('click3')) {
      return 'نقرات 3';
    }
    if (path.contains('success1')) {
      return 'نجاح 1';
    }
    if (path.contains('success2')) {
      return 'نجاح 2';
    }
    if (path.contains('delete1')) {
      return 'حذف 1';
    }
    if (path.contains('delete2')) {
      return 'حذف 2';
    }
    // Add more mappings as needed
    return 'مخصص';
  }

  void _showBackgroundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BackgroundPickerSheet(
        onSelect: (type, value) async {
          if (type == BackgroundService.typeAsset) {
            await BackgroundService.setAssetBackground(value);
            setState(() {
              _backgroundType = type;
            });
            if (mounted) {
              if (!context.mounted) return;
              Navigator.pop(context);
              AppSnackBar.success(context, 'تم تحديث الخلفية');
            }
          } else if (type == BackgroundService.typeCustom) {
            final XFile? image = await _picker.pickImage(
              source: ImageSource.gallery,
            );
            if (image != null) {
              await BackgroundService.setCustomBackground(image.path);
              setState(() {
                _backgroundType = type;
              });
              // Refresh full settings to get correct path
              await BackgroundService.loadSettings();
              setState(() {
                _backgroundType = BackgroundService.backgroundType;
              });

              if (!context.mounted) return;
              if (mounted) {
                Navigator.pop(context);
                AppSnackBar.success(context, 'تم تحديث الخلفية');
              }
            }
          }
        },
      ),
    );
  }

  void _showFontPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر الخط',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: FontService.availableFonts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final fontKey = FontService.availableFonts.keys.elementAt(
                    index,
                  );
                  final fontName = FontService.availableFonts[fontKey]!;
                  final isSelected = _selectedFont == fontKey;

                  return InkWell(
                    onTap: () async {
                      await FontService.setFont(fontKey);
                      setState(() => _selectedFont = fontKey);
                      if (mounted) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              fontName,
                              style: FontService.getFontTextStyle(
                                fontKey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSoundPicker(String type) {
    List<String> sounds = [];
    if (type == 'click') sounds = SoundService.availableClickSounds;
    if (type == 'success') sounds = SoundService.availableSuccessSounds;
    if (type == 'delete') sounds = SoundService.availableDeleteSounds;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'نغمة ${type == 'click'
                  ? 'النقر'
                  : type == 'success'
                  ? 'النجاح'
                  : 'الحذف'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<PlayerState>(
                stream: SoundService.onPlayerStateChanged,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data == PlayerState.playing;
                  final currentSound = SoundService.currentPlayingSound;

                  return ListView.builder(
                    itemCount: sounds.length,
                    itemBuilder: (context, index) {
                      final sound = sounds[index];
                      final isSelected =
                          (type == 'click' && _selectedClickSound == sound) ||
                          (type == 'success' &&
                              _selectedSuccessSound == sound) ||
                          (type == 'delete' && _selectedDeleteSound == sound);

                      final isThisSoundPlaying =
                          isPlaying && currentSound == sound;

                      return ListTile(
                        title: Text(_getSoundName(sound)),
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isThisSoundPlaying
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            color: isThisSoundPlaying
                                ? Colors.red
                                : Theme.of(context).primaryColor,
                          ),
                          onPressed: () {
                            if (isThisSoundPlaying) {
                              SoundService.stopAllSounds();
                            } else {
                              SoundService.previewSound(sound);
                            }
                          },
                        ),
                        onTap: () async {
                          // Preview sound on tap
                          if (isThisSoundPlaying) {
                            SoundService.stopAllSounds();
                          } else {
                            SoundService.previewSound(sound);
                          }

                          if (type == 'click') {
                            await SoundService.setClickSound(sound);
                          }
                          if (type == 'success') {
                            await SoundService.setSuccessSound(sound);
                          }
                          if (type == 'delete') {
                            await SoundService.setDeleteSound(sound);
                          }

                          setState(() {
                            if (type == 'click') {
                              _selectedClickSound = sound;
                            }
                            if (type == 'success') {
                              _selectedSuccessSound = sound;
                            }
                            if (type == 'delete') {
                              _selectedDeleteSound = sound;
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApiKeyDialog() {
    // Need to get key first
    ApiKeyService.getApiKey().then((currentKey) {
      if (!mounted) return;
      // Don't show default key in edit field if it's default
      final displayKey = ApiKeyService.defaultGeminiKeys.contains(currentKey)
          ? ''
          : currentKey;
      final controller = TextEditingController(text: displayKey);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('مفتاح Google Gemini API'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل مفتاح API الخاص بك لتفعيل الميزات الذكية',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://aistudio.google.com/app/apikey'),
                ),
                child: const Text('الحصول على مفتاح API'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final newKey = controller.text.trim();
                if (newKey.isEmpty) {
                  await ApiKeyService.clearApiKey();
                } else {
                  await ApiKeyService.saveApiKey(newKey);
                }

                await GeminiService.initialize();
                await _checkApiKey(); // Update UI state

                if (!mounted) return;
                if (mounted) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  AppSnackBar.success(context, 'تم حفظ مفتاح API');
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _showBackupOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.cloud_upload, color: Colors.white),
              ),
              title: const Text('إنشاء نسخة احتياطية'),
              subtitle: const Text('حفظ بياناتك في ملف خارجي'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final path = await BackupService().createBackup();
                  if (mounted && path != null) {
                    if (!mounted) return;
                    AppSnackBar.success(context, 'تم حفظ النسخة: $path');
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackBar.error(context, 'فشل النسخ الاحتياطي: $e');
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.cloud_download, color: Colors.white),
              ),
              title: const Text('استعادة نسخة احتياطية'),
              subtitle: const Text('استرجاع البيانات من ملف'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final success = await BackupService().restoreBackup();
                  if (mounted) {
                    if (success) {
                      AppSnackBar.success(
                        context,
                        'تمت الاستعادة بنجاح. يرجى إعادة تشغيل التطبيق لتطبيق الاستعادة.',
                        duration: const Duration(seconds: 6),
                      );
                    } else {
                      AppSnackBar.info(context, 'تم إلغاء الاستعادة');
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackBar.error(context, 'فشل الاستعادة: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'حذف كافة البيانات؟',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'سيتم حذف جميع المهام والملاحظات والإعدادات نهائياً. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              // 1. Delete DB tables
              final db = await DatabaseService().database;
              await db.delete('tasks');
              await db.delete('notes');
              await db.delete('folders');

              // 2. Clear state
              if (mounted) {
                if (!context.mounted) return;
                final taskProvider = Provider.of<TaskProvider>(
                  context,
                  listen: false,
                );
                final noteProvider = Provider.of<NoteProvider>(
                  context,
                  listen: false,
                );

                // Manually refresh providers if possible, or heavily suggest reload
                // Assuming providers have a refresh method or we rely on rebuild
                taskProvider.loadTasks();
                noteProvider.loadNotes();
              }

              if (mounted) {
                if (!context.mounted) return;
                AppSnackBar.success(context, 'تم حذف البيانات بنجاح');
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: _showAvatarPicker,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _userName.isNotEmpty ? _userName : 'صديقي العزيز',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'أهلاً بك',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            RoyalAvatarFrame(avatar: _userAvatar, size: 40),
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'اختر صورتك الشخصية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 11, // 10 pre-made + 1 gallery
                separatorBuilder: (context, index) => const SizedBox(width: 15),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildGalleryOption();
                  }
                  final avatarId = 'avatar_$index';
                  return _buildAvatarOption(avatarId);
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryOption() {
    return GestureDetector(
      onTap: () async {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          await UserService.saveUserAvatar(image.path);
          setState(() {
            _userAvatar = image.path;
          });
          if (mounted) Navigator.pop(context);
        }
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.add_a_photo_outlined, color: Colors.amber),
          ),
          const SizedBox(height: 8),
          const Text('المعرض', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAvatarOption(String avatarId) {
    final isSelected = _userAvatar == avatarId;
    return GestureDetector(
      onTap: () async {
        await UserService.saveUserAvatar(avatarId);
        setState(() {
          _userAvatar = avatarId;
        });
        if (mounted) Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.amber : Colors.transparent,
                width: 2,
              ),
            ),
            child: RoyalAvatarFrame(avatar: avatarId, size: 60),
          ),
          const SizedBox(height: 8),
          Text(
            'أفاتار ${avatarId.split('_')[1]}',
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.amber : null,
            ),
          ),
        ],
      ),
    );
  }
}

// === Custom Widgets for Settings Layout ===

class RoyalAvatarFrame extends StatelessWidget {
  final String avatar;
  final double size;

  const RoyalAvatarFrame({super.key, required this.avatar, required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Outer Glow
        Container(
          width: size + 10,
          height: size + 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        // Gold Frame
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFB8860B), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1A1A2E), // Deep background for the image
            ),
            child: ClipOval(child: _buildAvatarImage()),
          ),
        ),
        // Royal Ornament (Small crown or emblem)
        Positioned(
          top: -12,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 1),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A2E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium, // Crown-like icon
                    color: Colors.amber,
                    size: 14, // Shrinked from 24
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    if (avatar.startsWith('avatar_')) {
      // Pre-made avatars
      final index = int.tryParse(avatar.split('_')[1]) ?? 1;
      final icons = [
        Icons.person,
        Icons.face,
        Icons.auto_awesome,
        Icons.rocket_launch,
        Icons.star,
        Icons.favorite,
        Icons.psychology,
        Icons.lightbulb,
        Icons.shield,
        Icons.bolt,
      ];
      final colors = [
        Colors.blue,
        Colors.green,
        Colors.purple,
        Colors.orange,
        Colors.red,
        Colors.pink,
        Colors.teal,
        Colors.amber,
        Colors.indigo,
        Colors.cyan,
      ];

      final color = colors[(index - 1) % colors.length];

      return Container(
        color: color.withValues(alpha: 0.1),
        child: Icon(
          icons[(index - 1) % icons.length],
          size: size * 0.5,
          color: color,
        ),
      );
    } else {
      // Custom image file
      return Image.file(
        File(avatar),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, size: 50, color: Colors.grey),
      );
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        GlassContainer(
          opacity: 0.2, // Increased opacity for better contrast as requested
          blur: 15,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(
              alpha: 0.2,
            ), // Colored border based on section
            width: 1,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? child;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                )
              : null,
          trailing: trailing,
        ),
        if (child != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _ThemeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                    ),
                  ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundPickerSheet extends StatelessWidget {
  final Function(String type, String value) onSelect;

  const _BackgroundPickerSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر الخلفية',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: BackgroundService.availableBackgrounds.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              if (index == BackgroundService.availableBackgrounds.length) {
                return _buildCustomOption(context);
              }
              final bg = BackgroundService.availableBackgrounds[index];
              return _buildBackgroundOption(context, bg);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomOption(BuildContext context) {
    return InkWell(
      onTap: () => onSelect(BackgroundService.typeCustom, ''),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            const Text('مخصص', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundOption(BuildContext context, Map<String, String> bg) {
    return InkWell(
      onTap: () => onSelect(BackgroundService.typeAsset, bg['path']!),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: AssetImage(bg['path']!),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
