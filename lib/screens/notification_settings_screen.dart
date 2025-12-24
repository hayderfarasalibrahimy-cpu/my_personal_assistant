import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/alarm_service.dart';
import '../services/sound_service.dart';
import '../services/permission_service.dart';
import '../utils/app_snackbar.dart';

/// شاشة إعدادات الإشعارات والتنبيهات
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _notificationsEnabled = NotificationService.notificationsEnabled;
  bool _taskRemindersEnabled = NotificationService.taskRemindersEnabled;
  bool _aiNotificationsEnabled = NotificationService.aiNotificationsEnabled;
  bool _alarmsEnabled = AlarmService.alarmsEnabled;
  double _alarmVolume = AlarmService.alarmVolume;
  String _selectedAlarmSound = AlarmService.alarmSound;
  Timer? _soundPollingTimer;
  bool _isAnySoundPlaying = false;

  // استخدام قائمة الأصوات من AlarmService
  List<Map<String, String>> get _alarmSounds =>
      AlarmService.availableAlarmSounds;

  @override
  void initState() {
    super.initState();
    // مؤقت لمراقبة حالة تشغيل الصوت لتحديث الواجهة
    _soundPollingTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      final isPlaying =
          SoundService.isSoundPlaying || AlarmService().isAlarmPlaying;
      if (isPlaying != _isAnySoundPlaying) {
        if (mounted) setState(() => _isAnySoundPlaying = isPlaying);
      }
    });
  }

  @override
  void dispose() {
    _soundPollingTimer?.cancel();
    SoundService.stopAllSounds();
    AlarmService().stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAmoled = theme.scaffoldBackgroundColor == Colors.black;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الإشعارات والتنبيهات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قسم الإشعارات العامة
          _buildSectionHeader('🔔 الإشعارات', 'التحكم في إشعارات التطبيق'),
          _buildSettingsCard([
            _buildSwitchTile(
              title: 'تفعيل الإشعارات',
              subtitle: 'السماح للتطبيق بإرسال إشعارات',
              icon: Icons.notifications_active,
              value: _notificationsEnabled,
              onChanged: (value) async {
                setState(() => _notificationsEnabled = value);
                await NotificationService().setNotificationsEnabled(value);
              },
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              title: 'تذكيرات المهام',
              subtitle: 'إشعارات تذكير بالمهام المجدولة',
              icon: Icons.task_alt,
              value: _taskRemindersEnabled,
              enabled: _notificationsEnabled,
              onChanged: (value) async {
                setState(() => _taskRemindersEnabled = value);
                await NotificationService().setTaskRemindersEnabled(value);
              },
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              title: 'إشعارات الذكاء الاصطناعي',
              subtitle: 'السماح للمساعد بإرسال إشعارات',
              icon: Icons.smart_toy,
              value: _aiNotificationsEnabled,
              enabled: _notificationsEnabled,
              onChanged: (value) async {
                setState(() => _aiNotificationsEnabled = value);
                await NotificationService().setAiNotificationsEnabled(value);
              },
            ),
          ]),

          const SizedBox(height: 24),

          // قسم المنبهات
          _buildSectionHeader('⏰ المنبهات الصوتية', 'إعدادات صوت المنبه'),
          _buildSettingsCard([
            _buildSwitchTile(
              title: 'تفعيل المنبهات',
              subtitle: 'السماح بتشغيل المنبهات الصوتية',
              icon: Icons.alarm,
              value: _alarmsEnabled,
              onChanged: (value) async {
                setState(() => _alarmsEnabled = value);
                await AlarmService().setAlarmsEnabled(value);
              },
            ),
            const Divider(height: 1),
            // مستوى الصوت
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        color: _alarmsEnabled
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'مستوى صوت المنبه',
                          style: TextStyle(
                            fontSize: 16,
                            color: _alarmsEnabled ? null : Colors.grey,
                          ),
                        ),
                      ),
                      Text(
                        '${(_alarmVolume * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _alarmsEnabled
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _alarmVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: _alarmsEnabled
                        ? (value) async {
                            setState(() => _alarmVolume = value);
                            await AlarmService().setAlarmVolume(value);
                          }
                        : null,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // اختيار صوت المنبه
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        color: _alarmsEnabled
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'صوت المنبه',
                        style: TextStyle(
                          fontSize: 16,
                          color: _alarmsEnabled ? null : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _alarmSounds.map((sound) {
                      final isSelected = _selectedAlarmSound == sound['path'];
                      return ChoiceChip(
                        avatar: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                        label: Text(sound['name']!),
                        selected: isSelected,
                        onSelected: _alarmsEnabled
                            ? (selected) async {
                                if (selected) {
                                  setState(
                                    () => _selectedAlarmSound = sound['path']!,
                                  );
                                  await AlarmService().setAlarmSound(
                                    sound['path']!,
                                  );
                                  // تشغيل معاينة
                                  SoundService.previewSound(
                                    sound['path']!.replaceFirst(
                                      'assets/sounds/',
                                      '',
                                    ),
                                  );
                                }
                              }
                            : null,
                        selectedColor: Colors.green.shade700,
                        backgroundColor: isAmoled ? Colors.grey.shade900 : null,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // أزرار الاختبار
          _buildSectionHeader('🧪 اختبار', 'تجربة الإشعارات والمنبهات'),
          _buildSettingsCard([
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isAmoled ? Colors.blue.shade900 : Colors.blue)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications,
                  color: isAmoled ? Colors.blue.shade300 : Colors.blue,
                ),
              ),
              title: const Text('اختبار إشعار'),
              subtitle: const Text('إرسال إشعار تجريبي'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _notificationsEnabled
                  ? () async {
                      await NotificationService().showNotification(
                        title: 'اختبار الإشعارات',
                        body: 'هذا إشعار تجريبي من مذكرة الحياة 🎉',
                      );
                      if (!context.mounted) return;
                      AppSnackBar.success(context, 'تم إرسال الإشعار ✓');
                    }
                  : null,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isAmoled ? Colors.orange.shade900 : Colors.orange)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.alarm,
                  color: isAmoled ? Colors.orange.shade300 : Colors.orange,
                ),
              ),
              title: const Text('اختبار منبه'),
              subtitle: const Text('تشغيل صوت المنبه لثواني'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _alarmsEnabled
                  ? () async {
                      await AlarmService().playAlarm(
                        title: 'اختبار المنبه',
                        body: 'هذا منبه تجريبي',
                        loop: false,
                        showNotification: false,
                      );
                      if (!context.mounted) return;
                      AppSnackBar.warning(context, 'جاري تشغيل المنبه... 🔔');
                      // إيقاف بعد 3 ثواني
                      await Future.delayed(const Duration(seconds: 3));
                      await AlarmService().stopAlarm();
                    }
                  : null,
            ),
          ]),

          const SizedBox(height: 24),

          // قسم الأذونات
          _buildSectionHeader('🔐 الأذونات', 'السماح للتطبيق بالعمل بشكل صحيح'),
          _buildSettingsCard([
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications, color: Colors.green),
              ),
              title: const Text('إذن الإشعارات'),
              subtitle: const Text('السماح بإرسال الإشعارات'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final granted = await PermissionService()
                    .requestNotificationPermission();
                if (!context.mounted) return;
                if (granted) {
                  AppSnackBar.success(context, 'تم منح الإذن ✓');
                } else {
                  AppSnackBar.error(context, 'تم رفض الإذن ✗');
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isAmoled ? Colors.purple.shade900 : Colors.purple)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.alarm,
                  color: isAmoled ? Colors.purple.shade300 : Colors.purple,
                ),
              ),
              title: const Text('إذن المنبهات الدقيقة'),
              subtitle: const Text('السماح بجدولة المنبهات'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final granted = await PermissionService()
                    .requestExactAlarmPermission();
                if (!context.mounted) return;
                if (granted) {
                  AppSnackBar.success(context, 'تم منح الإذن ✓');
                } else {
                  AppSnackBar.error(context, 'تم رفض الإذن ✗');
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isAmoled ? Colors.amber.shade900 : Colors.amber)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.battery_saver,
                  color: isAmoled ? Colors.amber.shade300 : Colors.amber,
                ),
              ),
              title: const Text('استثناء توفير البطارية'),
              subtitle: const Text('السماح بالعمل في الخلفية'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final granted = await PermissionService()
                    .requestBatteryOptimizationExemption();
                if (!context.mounted) return;
                if (granted) {
                  AppSnackBar.success(context, 'تم منح الإذن ✓');
                } else {
                  AppSnackBar.warning(context, 'افتح الإعدادات يدوياً');
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isAmoled ? Colors.indigo.shade900 : Colors.indigo)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings,
                  color: isAmoled ? Colors.indigo.shade300 : Colors.indigo,
                ),
              ),
              title: const Text('فتح إعدادات التطبيق'),
              subtitle: const Text('لمنح أذونات إضافية'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () async {
                await PermissionService.openSettings();
              },
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
      floatingActionButton: _isAnySoundPlaying
          ? FloatingActionButton.extended(
              onPressed: () async {
                await SoundService.stopAllSounds();
                await AlarmService().stopAlarm();
                setState(() => _isAnySoundPlaying = false);
              },
              backgroundColor: Colors.redAccent,
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text(
                'إيقاف الصوت',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: enabled ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
        ),
      ),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              (enabled && value ? Theme.of(context).primaryColor : Colors.grey)
                  .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled && value
              ? Theme.of(context).primaryColor
              : Colors.grey,
        ),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}
