import 'package:flutter/material.dart';
import '../services/robot_settings_service.dart';
import '../services/user_preferences_service.dart';
import '../utils/app_snackbar.dart';

/// شاشة إعدادات الروبوت المساعد
class RobotSettingsScreen extends StatefulWidget {
  const RobotSettingsScreen({super.key});

  @override
  State<RobotSettingsScreen> createState() => _RobotSettingsScreenState();
}

class _RobotSettingsScreenState extends State<RobotSettingsScreen> {
  bool _soundEnabled = RobotSettingsService.soundEnabled;
  bool _vibrateEnabled = RobotSettingsService.vibrateEnabled;
  bool _particlesEnabled = RobotSettingsService.particlesEnabled;
  bool _eyeBlinkEnabled = RobotSettingsService.eyeBlinkEnabled;
  bool _armWaveEnabled = RobotSettingsService.armWaveEnabled;
  bool _draggable = RobotSettingsService.draggable;
  bool _autoGreet = RobotSettingsService.autoGreet;
  bool _smartReminders = RobotSettingsService.smartReminders;
  bool _showOnlyOnHome = RobotSettingsService.showOnlyOnHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الروبوت'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تعيين',
            onPressed: _resetSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('🎨 المظهر والحركة'),
          _buildSwitchTile(
            title: 'إظهار الروبوت',
            subtitle: 'عرض المساعد الشخصي في الشاشة الرئيسية',
            value: RobotSettingsService.isVisible,
            icon: Icons.visibility,
            onChanged: (value) async {
              setState(() {}); // إعادة بناء الشاشة لتحديث القيمة
              await RobotSettingsService.setIsVisible(value);
            },
          ),
          _buildSwitchTile(
            title: 'الظهور في الرئيسية فقط',
            subtitle: 'يختفي الروبوت عند الدخول لصفحات أخرى',
            value: _showOnlyOnHome,
            icon: Icons.home_repair_service,
            onChanged: (value) async {
              setState(() => _showOnlyOnHome = value);
              await RobotSettingsService.setShowOnlyOnHome(value);
            },
          ),
          const Divider(height: 32),

          _buildSectionHeader('✨ التأثيرات البصرية'),
          _buildSwitchTile(
            title: 'طرفة العين',
            subtitle: 'الروبوت يطرف عينيه تلقائياً',
            value: _eyeBlinkEnabled,
            icon: Icons.remove_red_eye,
            onChanged: (value) async {
              setState(() => _eyeBlinkEnabled = value);
              await RobotSettingsService.setEyeBlinkEnabled(value);
            },
          ),
          _buildSwitchTile(
            title: 'تلويح الأذرع',
            subtitle: 'الروبوت يلوح بيديه عند الترحيب',
            value: _armWaveEnabled,
            icon: Icons.waving_hand,
            onChanged: (value) async {
              setState(() => _armWaveEnabled = value);
              await RobotSettingsService.setArmWaveEnabled(value);
            },
          ),
          _buildSwitchTile(
            title: 'الجسيمات المتطايرة',
            subtitle: 'نجوم وقلوب تطير عند الاحتفال',
            value: _particlesEnabled,
            icon: Icons.auto_awesome,
            onChanged: (value) async {
              setState(() => _particlesEnabled = value);
              await RobotSettingsService.setParticlesEnabled(value);
            },
          ),
          const Divider(height: 32),

          _buildSectionHeader('🔊 الأصوات والاهتزاز'),
          _buildSwitchTile(
            title: 'الأصوات',
            subtitle: 'تشغيل أصوات عند التفاعل',
            value: _soundEnabled,
            icon: Icons.volume_up,
            onChanged: (value) async {
              setState(() => _soundEnabled = value);
              await RobotSettingsService.setSoundEnabled(value);
            },
          ),
          _buildSwitchTile(
            title: 'الاهتزاز',
            subtitle: 'اهتزاز عند التنبيهات المهمة',
            value: _vibrateEnabled,
            icon: Icons.vibration,
            onChanged: (value) async {
              setState(() => _vibrateEnabled = value);
              await RobotSettingsService.setVibrateEnabled(value);
            },
          ),
          const Divider(height: 32),

          _buildSectionHeader('🎮 التفاعل'),
          _buildSwitchTile(
            title: 'السحب والإفلات',
            subtitle: 'تحريك الروبوت بالسحب',
            value: _draggable,
            icon: Icons.open_with,
            onChanged: (value) async {
              setState(() => _draggable = value);
              await RobotSettingsService.setDraggable(value);
            },
          ),
          // زر إعادة تعيين مكان الروبوت
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                Icons.my_location,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('إعادة تعيين مكان الروبوت'),
              subtitle: const Text(
                'إرجاع الروبوت للموقع الافتراضي',
                style: TextStyle(fontSize: 12),
              ),
              trailing: FilledButton.icon(
                onPressed: _resetRobotPosition,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('إعادة'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ),
          const Divider(height: 32),

          _buildSectionHeader('🧠 الذكاء الصناعي'),
          _buildSwitchTile(
            title: 'التحية التلقائية',
            subtitle: 'الروبوت يحييك حسب الوقت',
            value: _autoGreet,
            icon: Icons.waving_hand_outlined,
            onChanged: (value) async {
              setState(() => _autoGreet = value);
              await RobotSettingsService.setAutoGreet(value);
            },
          ),
          _buildSwitchTile(
            title: 'التذكيرات الذكية',
            subtitle: 'تذكيرات تلقائية بالمهام',
            value: _smartReminders,
            icon: Icons.lightbulb_outline,
            onChanged: (value) async {
              setState(() => _smartReminders = value);
              await RobotSettingsService.setSmartReminders(value);
            },
          ),
          const Divider(height: 32),

          _buildSectionHeader('🎨 التخصيص المتقدم'),
          _buildPlatformStyleTile(),
          _buildColorPickerTile(
            'لون الأذرع والأيدي',
            RobotSettingsService.armsColor,
            (hex) => RobotSettingsService.setArmsColor(hex),
          ),
          _buildColorPickerTile(
            'لون الأرجل والأقدام',
            RobotSettingsService.legsColor,
            (hex) => RobotSettingsService.setLegsColor(hex),
          ),
          _buildColorPickerTile(
            'لون الفم (Mouth)',
            RobotSettingsService.mouthColor,
            (hex) => RobotSettingsService.setMouthColor(hex),
          ),
          _buildColorPickerTile(
            'لون الهوائي (Antenna)',
            RobotSettingsService.antennaColor,
            (hex) => RobotSettingsService.setAntennaColor(hex),
          ),
          _buildColorPickerTile(
            'لون الأذنين (Ears)',
            RobotSettingsService.earsColor,
            (hex) => RobotSettingsService.setEarsColor(hex),
          ),
          _buildColorPickerTile(
            'لون العيون الطاقية',
            RobotSettingsService.eyesColor,
            (hex) => RobotSettingsService.setEyesColor(hex),
          ),
          _buildColorPickerTile(
            'حافة العيون (Eye Rim)',
            RobotSettingsService.eyesRimColor,
            (hex) => RobotSettingsService.setEyesRimColor(hex),
          ),
          _buildColorPickerTile(
            'خلفية العيون (Eye BG)',
            RobotSettingsService.eyesBgColor,
            (hex) => RobotSettingsService.setEyesBgColor(hex),
          ),
          _buildColorPickerTile(
            'لون توهج الطاقة (Glow)',
            RobotSettingsService.glowColor,
            (hex) => RobotSettingsService.setGlowColor(hex),
          ),
          _buildColorPickerTile(
            'لون المنصة (Platform)',
            RobotSettingsService.platformColor,
            (hex) => RobotSettingsService.setPlatformColor(hex),
          ),
        ],
      ),
    );
  }

  final List<Color> _premiumColors = [
    const Color(0xFF2525AD), // Lottie Blue
    const Color(0xFF7B70EE), // Lavender
    const Color(0xFF4C4CFF), // Electric Blue
    const Color(0xFF00D2FF), // Neon Blue
    const Color(0xFF00E676), // Neon Green
    const Color(0xFF64FFDA), // Teal Neon
    const Color(0xFF1DE9B6), // Mint
    const Color(0xFFFFD600), // Bright Yellow
    const Color(0xFFFFAB00), // Amber
    const Color(0xFFFF6D00), // Orange
    const Color(0xFFFF3D00), // Deep Orange
    const Color(0xFFFF5252), // Pulse Red
    const Color(0xFFFF1744), // Crimson
    const Color(0xFFF50057), // Rose
    const Color(0xFFE91E63), // Pink
    const Color(0xFFD500F9), // Neon Purple
    const Color(0xFFAB47BC), // Purple
    const Color(0xFF651FFF), // Indigo Neon
    const Color(0xFF3D5AFE), // Royal Blue
    const Color(0xFF2979FF), // Sky Blue
    const Color(0xFF00B0FF), // Cyan
    const Color(0xFFB0BEC5), // Silver
    const Color(0xFF78909C), // Graphite
    const Color(0xFF263238), // Midnight
    const Color(0xFF4E342E), // Brown
  ];

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Widget _buildPlatformStyleTile() {
    final style = RobotSettingsService.platformStyle;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نمط المنصة (Platform)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStyleButton('بدون', 'none', style == 'none'),
                _buildStyleButton('كلاسيك', 'classic', style == 'classic'),
                _buildStyleButton('مودرن', 'modern', style == 'modern'),
                _buildStyleButton('الاثنين', 'both', style == 'both'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleButton(String label, String value, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        await RobotSettingsService.setPlatformStyle(value);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : null,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPickerTile(
    String title,
    String currentHex,
    Function(String) onSelected,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse(currentHex.replaceFirst('#', 'FF'), radix: 16),
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _premiumColors.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // زر اختيار لون مخصص
                    return GestureDetector(
                      onTap: () =>
                          _showCustomColorPicker(title, currentHex, onSelected),
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red,
                              Colors.yellow,
                              Colors.green,
                              Colors.cyan,
                              Colors.blue,
                              const Color(0xFFFF00FF), // Magenta
                              Colors.red,
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.colorize,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    );
                  }

                  final color = _premiumColors[index - 1];
                  final hex = _colorToHex(color);
                  final isSelected = hex == currentHex.toUpperCase();

                  return GestureDetector(
                    onTap: () async {
                      await onSelected(hex);
                      setState(() {});
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  /// عرض منتقي ألوان مخصص
  void _showCustomColorPicker(
    String title,
    String currentHex,
    Function(String) onSelected,
  ) {
    Color pickerColor = Color(
      int.parse(currentHex.replaceFirst('#', 'FF'), radix: 16),
    );
    HSLColor hslColor = HSLColor.fromColor(pickerColor);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color: hslColor.toColor(),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: hslColor.toColor().withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Hue Slider
                _buildHSLSlider(
                  'درجة اللون (Hue)',
                  hslColor.hue,
                  0,
                  360,
                  (val) =>
                      setDialogState(() => hslColor = hslColor.withHue(val)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.red,
                      Colors.yellow,
                      Colors.green,
                      Colors.cyan,
                      Colors.blue,
                      const Color(0xFFFF00FF), // Magenta
                      Colors.red,
                    ],
                  ),
                ),
                // Saturation Slider
                _buildHSLSlider(
                  'التشبع (Saturation)',
                  hslColor.saturation,
                  0,
                  1,
                  (val) => setDialogState(
                    () => hslColor = hslColor.withSaturation(val),
                  ),
                ),
                // Lightness Slider
                _buildHSLSlider(
                  'السطوع (Lightness)',
                  hslColor.lightness,
                  0,
                  1,
                  (val) => setDialogState(
                    () => hslColor = hslColor.withLightness(val),
                  ),
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
                  final hex = _colorToHex(hslColor.toColor());
                  await onSelected(hex);
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
                child: const Text('تطبيق'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHSLSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    Gradient? gradient,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Container(
          height: 12,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: gradient,
            color: gradient == null ? Colors.grey.shade200 : null,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Future<void> _resetSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين الإعدادات'),
        content: const Text('هل تريد إعادة جميع الإعدادات للقيم الافتراضية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await RobotSettingsService.resetToDefaults();
      setState(() {
        _soundEnabled = RobotSettingsService.soundEnabled;
        _vibrateEnabled = RobotSettingsService.vibrateEnabled;
        _particlesEnabled = RobotSettingsService.particlesEnabled;
        _eyeBlinkEnabled = RobotSettingsService.eyeBlinkEnabled;
        _armWaveEnabled = RobotSettingsService.armWaveEnabled;
        _draggable = RobotSettingsService.draggable;
        _autoGreet = RobotSettingsService.autoGreet;
        _smartReminders = RobotSettingsService.smartReminders;
        _showOnlyOnHome = RobotSettingsService.showOnlyOnHome;
      });

      if (mounted) {
        AppSnackBar.success(context, 'تم إعادة تعيين الإعدادات');
      }
    }
  }

  /// إعادة تعيين مكان الروبوت للموقع الافتراضي
  Future<void> _resetRobotPosition() async {
    await UserPreferencesService.clearAllPositions();

    if (mounted) {
      AppSnackBar.success(context, 'تم إعادة تعيين مكان الروبوت ✓');
    }
  }
}
