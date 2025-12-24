import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/alarm_service.dart';
import '../services/sound_service.dart';

/// شاشة المنبه الاحترافية - تظهر عند رنين المنبه
class AlarmScreen extends StatefulWidget {
  final String title;
  final String? body;
  final VoidCallback? onDismiss;
  final VoidCallback? onSnooze;

  const AlarmScreen({
    super.key,
    required this.title,
    this.body,
    this.onDismiss,
    this.onSnooze,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();

  /// عرض شاشة المنبه كـ Dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? body,
    VoidCallback? onDismiss,
    VoidCallback? onSnooze,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => AlarmScreen(
        title: title,
        body: body,
        onDismiss: onDismiss,
        onSnooze: onSnooze,
      ),
    );
  }
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Timer _timeUpdateTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();

    // تحديث الوقت
    _updateTime();
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
    });

    // أنيميشن النبض
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // أنيميشن الاهتزاز
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _shakeController.repeat(reverse: true);

    // اهتزاز الجهاز
    HapticFeedback.heavyImpact();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _timeUpdateTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.indigo.shade900,
                Colors.purple.shade900,
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // الوقت الحالي
                Text(
                  _currentTime,
                  style: const TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 40),

                // أيقونة المنبه المتحركة
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _pulseController,
                    _shakeController,
                  ]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.amber.shade400,
                                Colors.orange.shade600,
                                Colors.deepOrange.shade800,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.alarm,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),

                // عنوان المنبه
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                // الوصف
                if (widget.body != null && widget.body!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.body!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // الأزرار
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    children: [
                      // زر التأجيل
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.snooze,
                          label: 'تأجيل 5 دقائق',
                          color: Colors.blueGrey,
                          onTap: () {
                            SoundService.playClick();
                            AlarmService().snoozeAlarm(
                              snoozeMinutes: 5,
                              title: widget.title,
                              body: widget.body,
                            );
                            widget.onSnooze?.call();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      // زر الإيقاف
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.stop_circle,
                          label: 'إيقاف',
                          color: Colors.redAccent,
                          onTap: () {
                            SoundService.playClick();
                            AlarmService().stopAlarm();
                            widget.onDismiss?.call();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
