import 'package:flutter/material.dart';

import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import '../services/assistant_service.dart';
import '../services/robot_settings_service.dart';
import '../services/sound_service.dart';
import '../services/user_preferences_service.dart';

/// Widget للمساعد الشخصي بتصميم روبوت متطور
class AssistantCharacter extends StatefulWidget {
  final double? size;
  final String screenName; // اسم الشاشة لحفظ الموقع

  const AssistantCharacter({
    super.key,
    this.size,
    this.screenName = 'home', // القيمة الافتراضية
  });

  @override
  State<AssistantCharacter> createState() => _AssistantCharacterState();
}

class _AssistantCharacterState extends State<AssistantCharacter>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _bubbleController;
  late AnimationController _eyeBlinkController;
  late AnimationController _eyeMoveController;
  late AnimationController _eyeLookController;
  late AnimationController _armWaveController;
  late AnimationController _particlesController;
  late AnimationController _bounceController;
  late AnimationController _radarController;

  late Animation<double> _floatAnimation;
  late Animation<double> _bubbleScaleAnimation;
  late Animation<double> _bubbleFadeAnimation;
  late Animation<Offset> _eyeMoveAnimation;
  late Animation<Offset> _eyeLookAnimation;
  late Animation<double> _armWaveAnimation;
  late Animation<double> _bounceAnimation;

  Offset _position = Offset.zero;
  Offset _eyeLookTarget = Offset.zero;
  Timer? _lookTimer;

  // الاستماع لتغييرات الإعدادات
  final RobotSettingsNotifier _settingsNotifier = RobotSettingsNotifier();
  StreamSubscription<Offset>? _touchSubscription;
  Timer? _returnTimer;
  Offset _avoidanceOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    // الاستماع لتغييرات الإعدادات (مثل الحجم)
    _settingsNotifier.addListener(_onSettingsChanged);

    final speed = RobotSettingsService.animationSpeed;

    // Floating
    _floatController = AnimationController(
      duration: Duration(milliseconds: (3000 / speed).round()),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // Bubble
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _bubbleScaleAnimation = CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.elasticOut,
    );
    _bubbleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bubbleController, curve: Curves.easeIn));

    // Eye blink
    _eyeBlinkController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    if (RobotSettingsService.eyeBlinkEnabled) {
      _startBlinking();
    }

    // Eye movement (automatic)
    _eyeMoveController = AnimationController(
      duration: Duration(milliseconds: (2500 / speed).round()),
      vsync: this,
    )..repeat(reverse: true);

    _eyeMoveAnimation =
        Tween<Offset>(
          begin: const Offset(-0.12, 0),
          end: const Offset(0.12, 0),
        ).animate(
          CurvedAnimation(parent: _eyeMoveController, curve: Curves.easeInOut),
        );

    // Eye look at tap
    _eyeLookController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _eyeLookAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _eyeLookController, curve: Curves.easeOut),
        );

    // Arm wave
    _armWaveController = AnimationController(
      duration: Duration(milliseconds: (800 / speed).round()),
      vsync: this,
    );

    _armWaveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _armWaveController, curve: Curves.easeInOut),
    );

    // Particles
    _particlesController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Bounce
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: -20.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );

    // Radar Rotation
    _radarController = AnimationController(
      duration: const Duration(milliseconds: 600), // حركة أسرع للانتقال
      vsync: this,
    );

    // بدء الحركة العشوائية للعين
    _startRandomEyeMovement();

    // تحميل الموقع المحفوظ
    _loadSavedPosition();

    // الاستماع للمسات العالمية للهروب
    _touchSubscription = AssistantService().onGlobalTouchStream.listen(
      _handleGlobalTouch,
    );
  }

  void _handleGlobalTouch(Offset touchPos) {
    if (!mounted) return;

    // الحصول على موقع الروبوت العالمي
    final RenderBox? renderBox =
        _robotKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final robotGlobalPos = renderBox.localToGlobal(Offset.zero);
    final robotCenter =
        robotGlobalPos +
        Offset(renderBox.size.width / 2, renderBox.size.height / 2);

    final distance = (touchPos - robotCenter).distance;
    final robotSize = widget.size ?? RobotSettingsService.robotSize;
    final threshold = robotSize * 1.5;
    final innerThreshold =
        robotSize * 0.5; // منطقة النقر المباشر (داخل جسم الروبوت)

    // الهروب فقط إذا كان اللمس بجانب الروبوت وليس عليه مباشرة
    if (distance < threshold && distance > innerThreshold) {
      // حساب متجه الهروب
      final direction = (robotCenter - touchPos);
      final unitVector = Offset(
        direction.dx / distance,
        direction.dy / distance,
      );
      final force = (threshold - distance) / threshold;

      setState(() {
        // دفع الروبوت بعيداً
        _avoidanceOffset += unitVector * (force * 30);

        // تقييد الهروب لضمان عدم خروج الروبوت من الشاشة بشكل مبالغ فيه
        _avoidanceOffset = Offset(
          _avoidanceOffset.dx.clamp(-150.0, 150.0),
          _avoidanceOffset.dy.clamp(-150.0, 150.0),
        );
      });

      // ريستارت مؤقت العودة
      _resetReturnTimer();
    }
  }

  void _resetReturnTimer() {
    _returnTimer?.cancel();
    _returnTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _animateToHome();
      }
    });
  }

  void _animateToHome() {
    // العودة للمركز (الموقع المحفوظ)

    // أنيميشن العودة للموضع الأصلي
    // سنستخدم Tween و AnimationController إذا أردنا سلاسة فائقة،
    // لكن حالياً سنكتفي بتصفير الإزاحات تدريجياً عبر setState إذا لم نرد تعقيد الكود أكثر
    // أو الأفضل استخدام AnimatedContainer أو AnimatedTransform في الـ build

    setState(() {
      _avoidanceOffset = Offset.zero;
      _position = Offset.zero; // العودة للمكان الافتراضي للشاشة
    });

    // مسح الموقع المحفوظ إذا أردنا العودة "تماماً" للأصل،
    // لكن المستخدم قد يفضل العودة لآخر مكان وضعه هو فيه.
    // سأبقي _position = Offset.zero للعودة لمكان الـ Positioned الافتراضي
  }

  /// تحميل موقع الروبوت المحفوظ لهذه الشاشة
  void _loadSavedPosition() async {
    final savedPosition = await UserPreferencesService.getRobotPosition(
      widget.screenName,
    );
    if (savedPosition != null && mounted) {
      setState(() {
        _position = Offset(savedPosition['x']!, savedPosition['y']!);
      });
    }
  }

  /// حفظ موقع الروبوت عند انتهاء السحب
  void _savePosition() {
    UserPreferencesService.saveRobotPosition(
      widget.screenName,
      _position.dx,
      _position.dy,
    );
  }

  /// إعادة بناء الروبوت عند تغيير الإعدادات
  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startBlinking() async {
    while (mounted && RobotSettingsService.eyeBlinkEnabled) {
      await Future.delayed(Duration(seconds: 2 + math.Random().nextInt(3)));
      if (mounted && RobotSettingsService.eyeBlinkEnabled) {
        await _eyeBlinkController.forward();
        await _eyeBlinkController.reverse();
      }
    }
  }

  Timer? _randomEyeMoveTimer;

  void _startRandomEyeMovement() {
    // حركة أولية
    _scheduleNextEyeMove();
  }

  void _scheduleNextEyeMove() async {
    if (!mounted) return;

    // انتظار فترة عشوائية (ثبات العين) بين 2 و 6 ثواني
    final delay = Duration(milliseconds: 2000 + math.Random().nextInt(4000));

    _randomEyeMoveTimer = Timer(delay, () async {
      if (!mounted) return;

      // تحديد هدف عشوائي جديد (مدى أصغر لتكون الحركة واقعية)
      // X: -0.18 إلى 0.18
      // Y: -0.10 إلى 0.10
      final randX = (math.Random().nextDouble() * 0.36) - 0.18;
      final randY = (math.Random().nextDouble() * 0.20) - 0.10;
      final newTarget = Offset(randX, randY);

      // تحديث الأنيميشن للانتقال للهدف الجديد
      setState(() {
        final currentPos = _eyeMoveAnimation.value;
        _eyeMoveAnimation = Tween<Offset>(begin: currentPos, end: newTarget)
            .animate(
              CurvedAnimation(
                parent: _eyeMoveController,
                curve: Curves.elasticOut, // حركة مرنة وحيوية
              ),
            );
      });

      // تشغيل الانتقال
      _eyeMoveController.reset();
      await _eyeMoveController.forward();

      // تكرار العملية
      _scheduleNextEyeMove();
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (_lookTimer != null) {
      _lookTimer!.cancel();
    }

    final robotSize = widget.size ?? RobotSettingsService.robotSize;
    // حساب مركز الرأس/الوجه بدقة داخل الحاوية الموسعة التي تستقبل اللمس
    // الحاوية: width = robotSize * 1.6, height = (robotSize + 50) * 1.4
    // الروبوت مرسوم كـ Positioned(bottom: 22) وبداخله SizedBox(height: size + 50)
    final containerWidth = robotSize * 1.6;
    final containerHeight = (robotSize + 50) * 1.4;
    final robotBottomPadding = 22.0;
    final robotVisualHeight = robotSize + 50;
    final center = Offset(
      containerWidth / 2,
      containerHeight - robotBottomPadding - (robotVisualHeight / 2),
    );
    final tapPos = details.localPosition;

    // حساب متجه الاتجاه مع تطبيع أكثر واقعية (يمنع تمدد العين لحدود الوجه)
    final delta = tapPos - center;
    final maxDist = robotSize * 0.45;
    final nx = (delta.dx / maxDist).clamp(-1.0, 1.0);
    final ny = (delta.dy / maxDist).clamp(-1.0, 1.0);

    setState(() {
      // مدى حركة أصغر (بنسبة من الـ normalized vector)
      // القيم هنا بالـ painter space (Offset) وتؤثر مباشرة على الحدقة
      _eyeLookTarget = Offset(nx * 0.16, ny * 0.11);
    });

    _eyeLookAnimation =
        Tween<Offset>(
          begin: _eyeLookAnimation.value,
          end: _eyeLookTarget,
        ).animate(
          CurvedAnimation(parent: _eyeLookController, curve: Curves.easeOut),
        );

    _eyeLookController.forward(from: 0);

    // البقاء لمدة قبل العودة (إلا إذا تم النقر مرة أخرى)
    _lookTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _eyeLookAnimation =
            Tween<Offset>(
              begin: _eyeLookAnimation.value,
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _eyeLookController,
                curve: Curves.easeInOut,
              ),
            );
        _eyeLookController.forward(from: 0);
      }
    });

    _onTap();
  }

  void _onTap() {
    if (RobotSettingsService.soundEnabled) {
      SoundService.playClick();
    }
    if (RobotSettingsService.vibrateEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (RobotSettingsService.armWaveEnabled) {
      _armWaveController.forward(from: 0).then((_) {
        _armWaveController.reverse();
      });
    }
    if (RobotSettingsService.particlesEnabled) {
      _particlesController.forward(from: 0);
    }
    _bounceController.forward(from: 0).then((_) {
      _bounceController.reverse();
    });

    // إظهار الانزعاج
    AssistantService().showAnnoyed();
  }

  // Overlay entry للرسائل المنبثقة
  // OverlayEntry? _overlayEntry; // Removed overlay entry
  final GlobalKey _robotKey = GlobalKey();

  @override
  void dispose() {
    _touchSubscription?.cancel();
    _returnTimer?.cancel();
    // _removeOverlay(); // Removed
    _lookTimer?.cancel();
    _randomEyeMoveTimer?.cancel(); // Cancel random eye movement
    _settingsNotifier.removeListener(_onSettingsChanged);
    _floatController.dispose();
    _bubbleController.dispose();
    _eyeBlinkController.dispose();
    _eyeMoveController.dispose();
    _eyeLookController.dispose();
    _armWaveController.dispose();
    _particlesController.dispose();
    _bounceController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceFirst('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final assistant = AssistantService();
    final robotSize = widget.size ?? RobotSettingsService.robotSize;
    final platformStyle = RobotSettingsService.platformStyle;
    final glowColor = _hexToColor(RobotSettingsService.glowColor);
    final platformColor = _hexToColor(RobotSettingsService.platformColor);

    return ListenableBuilder(
      listenable: Listenable.merge([assistant, RobotSettingsNotifier()]),
      builder: (context, child) {
        // إدارة الرسائل المنبثقة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (assistant.showMessage && assistant.currentMessage.isNotEmpty) {
            _bubbleController.forward();
            // تشغيل الهوائي عند تغيير الحالة
            _radarController.forward(from: 0);
          } else {
            _bubbleController.reverse();
          }
        });

        return AnimatedContainer(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            _position.dx + _avoidanceOffset.dx,
            _position.dy + _avoidanceOffset.dy,
            0,
          ),
          child: GestureDetector(
            onPanStart: RobotSettingsService.draggable
                ? (_) {
                    setState(() {
                      _isDragging = true;
                    });
                    // Stop automatic eye movement while dragging
                    _eyeMoveController.stop();
                  }
                : null,
            onPanUpdate: RobotSettingsService.draggable
                ? (details) {
                    setState(() {
                      _isDragging = true;
                      _position += details.delta;
                      _resetReturnTimer(); // بدء مؤقت العودة عند السحب اليدوي أيضاً
                      final screenSize = MediaQuery.of(context).size;
                      // السماح للروبوت بالتحرك بحرية أكبر ليشمل كامل الشاشة
                      // maxY: أسفل الشاشة + حجم الروبوت لضمان عدم الاختفاء بالكامل
                      // minY: أعلى الشاشة (سالب) للسماح له بالوصول للقمة
                      final maxY = screenSize.height;
                      final minY = -screenSize.height;
                      final maxX = screenSize.width;
                      final minX = -screenSize.width;
                      _position = Offset(
                        _position.dx.clamp(minX, maxX),
                        _position.dy.clamp(minY, maxY),
                      );

                      // Eye follow drag direction (مدى أصغر حتى لا تصل للحافة)
                      final dx =
                          (details.delta.dx * 2).clamp(-10.0, 10.0) / 10.0;
                      final dy =
                          (details.delta.dy * 2).clamp(-10.0, 10.0) / 10.0;
                      _eyeLookTarget = Offset(dx * 0.16, dy * 0.11);

                      // تحديث مباشر للأنيميشن بدون توين لجعل الاستجابة فورية
                      _eyeLookAnimation = AlwaysStoppedAnimation(
                        _eyeLookTarget,
                      );
                    });
                  }
                : null,
            onPanEnd: RobotSettingsService.draggable
                ? (_) {
                    setState(() {
                      _isDragging = false;
                    });
                    _savePosition();
                    // Return eyes to center
                    setState(() {
                      _eyeLookTarget = Offset.zero;
                    });
                    _eyeLookAnimation =
                        Tween<Offset>(
                          begin:
                              _eyeLookTarget, // Current (which is the drag offset)
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _eyeLookController,
                            curve: Curves.elasticOut,
                          ),
                        );
                    _eyeLookController.forward(from: 0);
                  }
                : null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTapDown: (details) {
                  // جعل الروبوت قابلاً للنقر في كامل منطقة الحاوية الموسعة لضمان السهولة
                  _onTapDown(details);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color:
                      Colors.transparent, // يضمن التقاط اللمس في كامل المنطقة
                  key: _robotKey,
                  width: robotSize * 1.6, // توسيع منطقة التفاعل
                  height: (robotSize + 50) * 1.4,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _floatAnimation,
                      _bounceAnimation,
                    ]),
                    builder: (context, _) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          _floatAnimation.value + _bounceAnimation.value,
                        ),
                        child: RepaintBoundary(
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Platform (Classic)
                              if (platformStyle == 'classic' ||
                                  platformStyle == 'both')
                                Positioned(
                                  bottom: 0,
                                  child: CustomPaint(
                                    size: Size(robotSize * 0.7, 16),
                                    painter: PlatformPainter(
                                      color: platformColor.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                ),

                              // Glow Effect
                              Positioned(
                                bottom: 16,
                                child: Container(
                                  width: robotSize * 0.9,
                                  height: robotSize * 0.9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: glowColor.withValues(alpha: 0.3),
                                        blurRadius: 18,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Shadow
                              Positioned(
                                bottom: 14,
                                child: AnimatedBuilder(
                                  animation: _floatAnimation,
                                  builder: (context, _) {
                                    final scale =
                                        1.0 - (_floatAnimation.value / 50.0);
                                    final opacity =
                                        0.28 -
                                        (_floatAnimation.value / 80.0 * 0.12);
                                    return Container(
                                      width: robotSize * 0.5 * scale,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: opacity.clamp(0.0, 0.35),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: opacity.clamp(0.0, 0.25),
                                            ),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Robot
                              Positioned(
                                bottom: 22,
                                child: _buildRobot(
                                  assistant.currentState,
                                  robotSize,
                                ),
                              ),

                              // Particles
                              if (RobotSettingsService.particlesEnabled)
                                Positioned(
                                  bottom: robotSize * 0.5,
                                  child: AnimatedBuilder(
                                    animation: _particlesController,
                                    builder: (context, _) {
                                      return CustomPaint(
                                        size: Size(
                                          robotSize * 1.6,
                                          robotSize * 1.6,
                                        ),
                                        painter: ParticlesPainter(
                                          progress: _particlesController.value,
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              // Bubbles Stack (Stacked based on user request)
                              Positioned(
                                bottom: robotSize + 60,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      Alignment.center == Alignment.center
                                      ? CrossAxisAlignment.center
                                      : CrossAxisAlignment.center,
                                  children: assistant.activeMessages.map((msg) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: _buildBubble(msg['text']),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRobot(AssistantState state, double size) {
    // ألوان ثابتة للهوية البصرية (Lottie Identity)
    final bodyColor = const Color(0xFF2525AD);
    final faceColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF121212)
        : Colors.white;
    final cheeksColor = const Color(0xFFFF80AB);

    final armsColor = _hexToColor(RobotSettingsService.armsColor);
    final legsColor = _hexToColor(RobotSettingsService.legsColor);
    final eyesColor = _hexToColor(RobotSettingsService.eyesColor);
    final eyesRimColor = _hexToColor(RobotSettingsService.eyesRimColor);
    final eyesBgColor = _hexToColor(RobotSettingsService.eyesBgColor);
    final mouthColor = _hexToColor(RobotSettingsService.mouthColor);
    final antennaColor = _hexToColor(RobotSettingsService.antennaColor);
    final earsColor = _hexToColor(RobotSettingsService.earsColor);
    final platformColor = _hexToColor(RobotSettingsService.platformColor);
    final platformStyle = RobotSettingsService.platformStyle;

    final primaryColor = _getStateColor(state, bodyColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size + 50,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Platform (Modern Holographic Base)
          if (platformStyle == 'modern' || platformStyle == 'both')
            Positioned(
              bottom: -size * 0.45,
              left: (size - size * 1.8) / 2,
              width: size * 1.8,
              height: size * 0.6,
              child: CustomPaint(
                painter: RobotPlatformPainter(
                  color: platformColor,
                  animationValue: _radarController.value,
                ),
              ),
            ),

          // Legs
          Positioned(
            bottom: 0,
            child: CustomPaint(
              size: Size(size * 0.60, 28),
              painter: RobotLegsPainter(color: legsColor, isDark: isDark),
            ),
          ),

          // Body
          Positioned(
            bottom: 24,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ears (Behind Arms)
                  CustomPaint(
                    size: Size(size * 0.92, size * 0.92),
                    painter: RobotEarsPainter(
                      primaryColor: primaryColor,
                      earsColor: earsColor,
                    ),
                  ),

                  // Arms
                  AnimatedBuilder(
                    animation: _armWaveAnimation,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(size * 1.35, size * 0.92),
                        painter: RobotArmsPainter(
                          color: armsColor,
                          waveProgress: _armWaveAnimation.value,
                          isDark: isDark,
                        ),
                      );
                    },
                  ),

                  // Head
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _eyeBlinkController,
                      _eyeMoveController,
                      _eyeLookController,
                      _radarController,
                    ]),
                    builder: (context, _) {
                      final eyeOffset =
                          _eyeMoveAnimation.value + _eyeLookAnimation.value;
                      return CustomPaint(
                        size: Size(size * 0.92, size * 0.92),
                        painter: RobotPainter(
                          primaryColor: primaryColor,
                          eyesColor: eyesColor,
                          eyesRimColor: eyesRimColor,
                          eyesBgColor: eyesBgColor,
                          faceColor: faceColor,
                          mouthColor: mouthColor,
                          antennaColor: antennaColor,
                          cheeksColor: cheeksColor,
                          isDark: isDark,
                          eyeBlinkValue: _eyeBlinkController.value,
                          eyeOffset: eyeOffset,
                          state: state,
                          radarRotation: _radarController.value,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStateColor(AssistantState state, [Color? defaultColor]) {
    final baseColor = defaultColor ?? const Color(0xFF2525AD);
    // ألوان Lottie الهوية البصرية
    const lottieLavender = Color(0xFF7B70EE);

    switch (state) {
      case AssistantState.success:
      case AssistantState.celebrate:
        return Colors.green.shade400; // النجاح يبقى أخضر
      case AssistantState.sad:
      case AssistantState.deleting:
        return Colors.red.shade400; // الخطأ يبقى أحمر

      case AssistantState.thinking:
        return lottieLavender; // التفكير بلون اللافندر

      case AssistantState.happy:
      case AssistantState.excited:
      case AssistantState.greeting:
        return const Color(0xFF4C4CFF); // أزرق مشرق للفرح

      case AssistantState.annoyed:
        return Colors.deepOrange; // برتقالي للانزعاج

      default:
        return baseColor; // الوضع الطبيعي
    }
  }

  Widget _buildBubble(String message) {
    if (message.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _bubbleFadeAnimation,
      child: ScaleTransition(
        scale: _bubbleScaleAnimation,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // الفقاعة الرئيسية
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              constraints: const BoxConstraints(maxWidth: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // السهم المثلث يشير للأسفل (نحو فم الروبوت)
            CustomPaint(
              size: const Size(14, 8),
              painter: BubbleArrowPainter(
                color: Theme.of(context).colorScheme.surface,
                borderColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bubble Arrow Painter - رسم سهم الفقاعة المنبثق
class BubbleArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  BubbleArrowPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    // رسم الخلفية
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // رسم الحدود
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(BubbleArrowPainter oldDelegate) =>
      color != oldDelegate.color || borderColor != oldDelegate.borderColor;
}

/// Platform Painter - تصميم منصة عائمة 3D
class PlatformPainter extends CustomPainter {
  final Color color;

  PlatformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // === الحلقة الخارجية (هالة الطاقة) ===
    final outerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));

    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width, height: size.height),
      outerGlow,
    );

    // === المنصة الرئيسية 3D ===
    final platformPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: center,
          width: size.width * 0.8,
          height: size.height * 0.8,
        ),
      );

    // تدرج المنصة
    final platformGradient = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.8), _darken(color, 0.4)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.4));

    // ظل تحت المنصة
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 4),
        width: size.width * 0.8,
        height: size.height * 0.8,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawPath(platformPath, platformGradient);

    // === تفاصيل تكنولوجية على السطح ===
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // خطوط الشبكة
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.6,
        height: size.height * 0.6,
      ),
      gridPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.3,
        height: size.height * 0.3,
      ),
      gridPaint,
    );

    canvas.drawLine(
      center.translate(-size.width * 0.4, 0),
      center.translate(size.width * 0.4, 0),
      gridPaint,
    );
    canvas.drawLine(
      center.translate(0, -size.height * 0.4),
      center.translate(0, size.height * 0.4),
      gridPaint,
    );

    // === حافة مضيئة ===
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.8),
          color.withValues(alpha: 0.0),
        ],
        transform: const GradientRotation(math.pi / 4),
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.4));

    canvas.drawPath(platformPath, rimPaint);
  }

  Color _darken(Color c, double amount) {
    return Color.fromARGB(
      c.a.toInt(),
      (c.r * (1 - amount)).round().clamp(0, 255),
      (c.g * (1 - amount)).round().clamp(0, 255),
      (c.b * (1 - amount)).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(PlatformPainter oldDelegate) => oldDelegate.color != color;
}

/// Legs Painter - تصميم 3D
class RobotLegsPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  RobotLegsPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final legWidth = size.width * 0.22;
    final legHeight = size.height * 0.65;

    // ظل الأرجل
    final shadowPaint = Paint()
      ..color = const Color.fromARGB(255, 76, 74, 74).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25 + 2, 2, legWidth, legHeight),
        const Radius.circular(10),
      ),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.56 + 2, 2, legWidth, legHeight),
        const Radius.circular(10),
      ),
      shadowPaint,
    );

    // تدرج الأرجل 3D
    final legGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.9), // أسود زجاجي داكن
          Colors.black.withValues(alpha: 0.7), // انعكاس أخف
          Colors.black.withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, legWidth, legHeight));

    // الرجل اليسرى
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.24, 0, legWidth, legHeight),
        const Radius.circular(10),
      ),
      legGradient,
    );

    // حدود زجاجية بيضاء للساق اليسرى
    final glassLegBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.24, 0, legWidth, legHeight),
        const Radius.circular(10),
      ),
      glassLegBorder,
    );

    // === القدمين (Feet) - مواجهة للأمام ===
    // تغيير الشكل ليكون بيضاوياً عريضاً يواجه المشاهد
    // (footHighlight removed as it was defined inside _drawForwardFoot logic implicitly or duplicated)

    // القدم اليسرى (مواجهة)
    _drawForwardFoot(
      canvas,
      Offset(size.width * 0.25 + legWidth / 2, legHeight + 8),
      legWidth * 1.5, // عرض أكبر
      color,
    );

    // القدم اليمنى (مواجهة)
    _drawForwardFoot(
      canvas,
      Offset(size.width * 0.56 + legWidth / 2, legHeight + 8),
      legWidth * 1.5,
      color,
    );

    // تفاصيل الركبة (مفاصل)
    final kneePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // ركبة يسرى
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.24, legHeight * 0.45, legWidth, 4),
      kneePaint,
    );
    // ركبة يمنى
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.56, legHeight * 0.45, legWidth, 4),
      kneePaint,
    );

    // الرجل اليمنى
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.56, 0, legWidth, legHeight),
        const Radius.circular(10),
      ),
      legGradient,
    );

    // حدود زجاجية بيضاء للساق اليمنى
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.56, 0, legWidth, legHeight),
        const Radius.circular(10),
      ),
      glassLegBorder,
    );

    // انعكاس ضوئي على الأرجل
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(size.width * 0.26, 5),
      Offset(size.width * 0.26, legHeight - 5),
      highlightPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.58, 5),
      Offset(size.width * 0.58, legHeight - 5),
      highlightPaint,
    );

    // القدمين مع تأثير 3D
    final footRect1 = Rect.fromLTWH(
      size.width * 0.18,
      legHeight - 2,
      legWidth * 1.6,
      size.height - legHeight + 2,
    );
    final footRect2 = Rect.fromLTWH(
      size.width * 0.50,
      legHeight - 2,
      legWidth * 1.6,
      size.height - legHeight + 2,
    );

    // ظل القدمين
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        footRect1.translate(2, 2),
        const Radius.circular(8),
      ),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        footRect2.translate(2, 2),
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    // القدمين بتدرج
    final footGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lighten(color, 0.1), color, _darken(color, 0.2)],
      ).createShader(footRect1);

    canvas.drawRRect(
      RRect.fromRectAndRadius(footRect1, const Radius.circular(8)),
      footGradient,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(footRect2, const Radius.circular(8)),
      footGradient,
    );

    // خط انعكاس على القدمين
    final footHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.20, legHeight + 4),
      Offset(size.width * 0.34, legHeight + 4),
      footHighlight,
    );
    canvas.drawLine(
      Offset(size.width * 0.52, legHeight + 4),
      Offset(size.width * 0.66, legHeight + 4),
      footHighlight,
    );

    // حلقات معدنية على الأرجل
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          _darken(color, 0.3),
          _lighten(color, 0.3),
          _darken(color, 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, legWidth, 6))
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.23, legHeight * 0.4, legWidth + 2, 5),
        const Radius.circular(2),
      ),
      ringPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, legHeight * 0.4, legWidth + 2, 5),
        const Radius.circular(2),
      ),
      ringPaint,
    );
  }

  void _drawForwardFoot(
    Canvas canvas,
    Offset center,
    double width,
    Color color,
  ) {
    // رسم القدم كشكل بيضاوي مفلطح من الأسفل (نعل) وقبة من الأعلى
    final height = width * 0.6;

    final footRect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    final footPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.8),
          Colors.black.withValues(alpha: 0.95),
        ],
      ).createShader(footRect);

    // الجزء الرئيسي للقدم
    canvas.drawOval(footRect, footPaint);

    // نعل الحذاء (قاعدة داكنة)
    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(0, height * 0.2),
        width: width,
        height: height * 0.8,
      ),
      0,
      3.14, // نصف دائرة سفلية
      false,
      Paint()..color = _darken(color, 0.5),
    );

    // لمعة علوية (مقدمة الحذاء)
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, -height * 0.2),
        width: width * 0.6,
        height: height * 0.3,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.6), // لمعة أقوى
    );

    // حدود زجاجية بيضاء للقدم (White Glass Border)
    final glassFootBorder = Paint()
      ..color = Colors.white
          .withValues(alpha: 0.7) // وضوح عالي للحدود
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        0.5,
      ); // تأثير وهج خفيف

    canvas.drawOval(footRect, glassFootBorder);

    // حدود خارجية للقدم لزيادة الوضوح
    final footBorder = Paint()
      ..color = _darken(color, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(footRect, footBorder);
  }

  Color _lighten(Color c, double amount) {
    return Color.fromARGB(
      c.a.toInt(),
      (c.r + (255 - c.r) * amount).round().clamp(0, 255),
      (c.g + (255 - c.g) * amount).round().clamp(0, 255),
      (c.b + (255 - c.b) * amount).round().clamp(0, 255),
    );
  }

  Color _darken(Color c, double amount) {
    return Color.fromARGB(
      c.a.toInt(),
      (c.r * (1 - amount)).round().clamp(0, 255),
      (c.g * (1 - amount)).round().clamp(0, 255),
      (c.b * (1 - amount)).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(RobotLegsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}

/// Arms Painter - تصميم 3D
class RobotArmsPainter extends CustomPainter {
  final Color color;
  final double waveProgress;
  final bool isDark;

  RobotArmsPainter({
    required this.color,
    required this.waveProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final armWidth = 14.0;

    // إحداثيات الذراع اليسرى (مع التلويح - left wave)
    final waveY = waveProgress * -55;
    final leftStart = Offset(centerX - size.width * 0.23, centerY - 10);
    final leftEnd = Offset(centerX - size.width * 0.40, centerY + 35 + waveY);

    // إحداثيات الذراع اليمنى (تتحرك مع اليسرى لرفع اليدين معاً)
    final rightStart = Offset(centerX + size.width * 0.23, centerY - 10);
    final rightEnd = Offset(centerX + size.width * 0.40, centerY + 35 + waveY);

    // === ظل الأذرع ===
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = armWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    _drawArm(
      canvas,
      leftStart.translate(2, 2),
      leftEnd.translate(2, 2),
      shadowPaint,
    );
    _drawArm(
      canvas,
      rightStart.translate(2, 2),
      rightEnd.translate(2, 2),
      shadowPaint,
    );

    // === الأذرع بتدرج 3D ===
    // طبقة خارجية داكنة
    final darkPaint = Paint()
      ..color = _darken(color, 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = armWidth
      ..strokeCap = StrokeCap.round;

    _drawArm(canvas, leftStart, leftEnd, darkPaint);
    _drawArm(canvas, rightStart, rightEnd, darkPaint);

    // طبقة وسطى (اللون الأساسي)
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = armWidth - 4
      ..strokeCap = StrokeCap.round;

    _drawArm(canvas, leftStart, leftEnd, mainPaint);
    _drawArm(canvas, rightStart, rightEnd, mainPaint);

    // انعكاس ضوئي (خط فاتح)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    _drawArm(
      canvas,
      leftStart.translate(-2, -1),
      leftEnd.translate(-2, -1),
      highlightPaint,
    );
    _drawArm(
      canvas,
      rightStart.translate(2, -1),
      rightEnd.translate(2, -1),
      highlightPaint,
    );

    // === الأيدي الكروية 3D ===
    _drawHand3D(canvas, leftEnd, 11);
    _drawHand3D(canvas, rightEnd, 11);

    // === حلقات المعصم ===
    _drawWristRing(canvas, leftEnd.translate(0, -15));
    _drawWristRing(canvas, rightEnd.translate(0, -15));
  }

  void _drawArm(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + end.dx) / 2 + (start.dx < end.dx ? -15 : 15),
        (start.dy + end.dy) / 2,
        end.dx,
        end.dy,
      );
    canvas.drawPath(path, paint);
  }

  void _drawHand3D(Canvas canvas, Offset center, double radius) {
    // 1. رسم الأصابع (خلف الكف)

    // أصابع بتوزيع نصف دائري
    for (int i = -1; i <= 1; i++) {
      final angle = i * 0.5; // زاوية الميلان
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final fingerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, radius * 0.8),
          width: radius * 0.5,
          height: radius * 1.2,
        ),
        Radius.circular(radius * 0.25),
      );

      // تدرج للأصابع
      final fingerGradient = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_darken(color, 0.2), color, _lighten(color, 0.2)],
        ).createShader(fingerRect.outerRect);

      canvas.drawRRect(fingerRect, fingerGradient);

      // مفصل الإصبع
      canvas.drawCircle(
        Offset(0, radius * 1.2),
        radius * 0.2,
        Paint()..color = _darken(color, 0.3),
      );

      canvas.restore();
    }

    // 2. ظل الكف
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center.translate(2, 2), radius, shadowPaint);

    // 3. الكف بتدرج 3D (الرئيسي)
    final handGradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [_lighten(color, 0.3), color, _darken(color, 0.3)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, handGradient);

    // 4. تفاصيل ميكانيكية للكف (لوحة معدنية)
    final plateRect = Rect.fromCenter(
      center: center,
      width: radius * 1.2,
      height: radius * 0.8,
    );
    final plateRRect = RRect.fromRectAndRadius(
      plateRect,
      Radius.circular(radius * 0.2),
    );

    final platePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(plateRRect, platePaint);

    // 5. مسامير التثبيت (تفاصيل صغيرة)
    final screwPaint = Paint()..color = _darken(color, 0.5);
    canvas.drawCircle(center.translate(-radius * 0.4, 0), 1.5, screwPaint);
    canvas.drawCircle(center.translate(radius * 0.4, 0), 1.5, screwPaint);

    // 6. انعكاس ضوئي (لمعة)
    final shinePaint = Paint()..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(
      center.translate(-radius * 0.3, -radius * 0.4),
      radius * 0.3,
      shinePaint,
    );

    // 7. ضوء حالة (صغير في وسط الكف)
    final statusLightPaint = Paint()
      ..color = (isDark ? Colors.blueAccent : Colors.cyan).withValues(
        alpha: 0.8,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center.translate(0, radius * 0.2), 2, statusLightPaint);
  }

  void _drawWristRing(Canvas canvas, Offset center) {
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          _darken(color, 0.3),
          _lighten(color, 0.4),
          _darken(color, 0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 8));

    canvas.drawCircle(center, 8, ringPaint);

    // حافة الحلقة
    final edgePaint = Paint()
      ..color = _darken(color, 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 8, edgePaint);
  }

  Color _lighten(Color c, double amount) {
    return Color.fromARGB(
      c.a.toInt(),
      (c.r + (255 - c.r) * amount).round().clamp(0, 255),
      (c.g + (255 - c.g) * amount).round().clamp(0, 255),
      (c.b + (255 - c.b) * amount).round().clamp(0, 255),
    );
  }

  Color _darken(Color c, double amount) {
    return Color.fromARGB(
      c.a.toInt(),
      (c.r * (1 - amount)).round().clamp(0, 255),
      (c.g * (1 - amount)).round().clamp(0, 255),
      (c.b * (1 - amount)).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(RobotArmsPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}

/// Particles Painter - شرارات طاقة متوهجة
class ParticlesPainter extends CustomPainter {
  final double progress;

  ParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    for (int i = 0; i < 22; i++) {
      final angle = (i / 22) * 2 * math.pi;
      final distance = progress * 90; // مسافة أبعد قليلاً
      final x = size.width / 2 + math.cos(angle) * distance;
      final y = size.height / 2 + math.sin(angle) * distance - progress * 50;

      final opacity = (1 - progress).clamp(0.0, 1.0);
      final particleSize = 6 * (1 - progress * 0.3);

      Color baseColor;
      if (i % 3 == 0) {
        baseColor = Colors.cyanAccent;
      } else if (i % 3 == 1) {
        baseColor = Colors.purpleAccent;
      } else {
        baseColor = Colors.amberAccent;
      }

      // توهج الجسيمات
      final glowPaint = Paint()
        ..color = baseColor.withValues(alpha: opacity * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(Offset(x, y), particleSize + 2, glowPaint);

      final paint = Paint()
        ..color = baseColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      if (i % 2 == 0) {
        _drawStar(canvas, Offset(x, y), particleSize, paint);
      } else {
        canvas.drawCircle(Offset(x, y), particleSize * 0.7, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      // نجمة رباعية (تأثير لامع)
      final angle = (i * math.pi / 2);
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      final xInner = center.dx + size * 0.3 * math.cos(angle + math.pi / 4);
      final yInner = center.dy + size * 0.3 * math.sin(angle + math.pi / 4);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      path.lineTo(xInner, yInner);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Robot Painter - تصميم 3D احترافي
class RobotPainter extends CustomPainter {
  final Color primaryColor;
  final Color eyesColor;
  final Color eyesRimColor;
  final Color eyesBgColor;
  final Color faceColor;
  final Color mouthColor;
  final Color antennaColor;
  final Color cheeksColor;
  final bool isDark;
  final double eyeBlinkValue;
  final Offset eyeOffset;
  final AssistantState state;
  final double radarRotation;

  RobotPainter({
    required this.primaryColor,
    required this.eyesColor,
    required this.eyesRimColor,
    required this.eyesBgColor,
    required this.faceColor,
    required this.mouthColor,
    required this.antennaColor,
    required this.cheeksColor,
    required this.isDark,
    required this.eyeBlinkValue,
    required this.eyeOffset,
    required this.state,
    this.radarRotation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // مشتقات الألوان من اللون الأساسي للحفاظ على تفاعل الحالة
    // مشتقات الألوان من اللون الأساسي

    // === الآذان الجانبية (Ears) - Moved to RobotEarsPainter ===
    // وتمت الإزالة من هنا لتكون في طبقة خلفية منفصلة

    // === الطبقة الخلفية - الظل الخارجي (أقل شفافية) ===
    final outerShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(center.dx + 4, center.dy + 6),
      radius * 0.88,
      outerShadow,
    );

    // === الجسم الرئيسي (الرأس) - يعتمد على primaryColor (ألوان أكثر صلابة) ===
    final bodyGradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 1.0,
        colors: [
          _lighten(primaryColor, 0.25),
          primaryColor,
          _darken(primaryColor, 0.4),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.88, bodyGradient);

    // === تفاصيل الشاشة (Screen Outline) - أكثر وضوحاً ===
    final screenPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: radius * 1.4,
          height: radius * 1.0,
        ),
        const Radius.circular(30),
      ),
      screenPaint,
    );

    // === الحافة اللامعة (Rim) - تمت إزالتها بطلب المستخدم ===
    // final rimPaint = Paint() ...

    // === الوجه (أو الشاشة) - ألوان أكثر صلابة ===
    final faceGradient = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [_darken(faceColor, 0.2), _darken(faceColor, 0.5)]
                : [faceColor, _darken(faceColor, 0.2)],
          ).createShader(
            Rect.fromCenter(
              center: center,
              width: radius * 1.65,
              height: radius * 1.65,
            ),
          );

    // وجه مستطيل دائري قليلاً ليتناسب مع "الشاشة"
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: radius * 1.65,
        height: radius * 1.65,
      ),
      const Radius.circular(100),
    );
    canvas.drawRRect(faceRect, faceGradient);

    // === حافة داخلية للوجه (تفاصيل إضافية) ===
    final innerRimPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(faceRect, innerRimPaint);

    // === العيون (تصميم Lottie: Rounded Rect) ===
    _drawEye3D(canvas, center, radius, -1, eyeOffset, eyesColor); // عين يسار
    _drawEye3D(canvas, center, radius, 1, eyeOffset, eyesColor); // عين يمين

    // === الفم ===
    _drawMouth(canvas, center, radius);

    // === الهوائي (تصميم Lottie) ===
    _drawAntenna3D(canvas, center, radius, antennaColor, radarRotation);

    // === الخدود ===
    if (state == AssistantState.happy ||
        state == AssistantState.excited ||
        state == AssistantState.celebrate) {
      _drawCheeks(canvas, center, radius);
    }
  }

  /// رسم عين ثلاثية الأبعاد (Rounded Rect Style)
  void _drawEye3D(
    Canvas canvas,
    Offset center,
    double radius,
    int side,
    Offset offset,
    Color pupilColor,
  ) {
    // تغيير الشكل من دائري إلى مستطيل دائري (Squircle)
    final eyeX = center.dx + (side * radius * 0.29) + offset.dx * radius;
    final eyeY = center.dy - radius * 0.13 + offset.dy * radius;
    final eyeWidth = radius * 0.28; // أعرض قليلاً
    final eyeHeight =
        (eyeWidth * 1.1) * (1 - eyeBlinkValue * 0.96); // أطول قليلاً

    final eyeCenter = Offset(eyeX, eyeY);
    final eyeRect = Rect.fromCenter(
      center: eyeCenter,
      width: eyeWidth,
      height: eyeHeight,
    );
    final eyeRRect = RRect.fromRectAndRadius(
      eyeRect,
      const Radius.circular(12),
    );

    // ظل العين - أكثر وضوحاً
    final eyeShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(eyeRRect.shift(const Offset(2, 3)), eyeShadow);

    // خلفية العين - أكثر سطوعاً
    final eyeBg = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [eyesBgColor, _darken(eyesBgColor, 0.15)],
      ).createShader(eyeRect);
    canvas.drawRRect(eyeRRect, eyeBg);

    // حافة العين
    final eyeRimPaint = Paint()
      ..color = eyesRimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(eyeRRect, eyeRimPaint);

    // بؤبؤ العين (مستطيل دائري أيضاً)
    // تغيير البؤبؤ في حالة الانزعاج (أصغر وأعلى)
    final pupilScale = state == AssistantState.annoyed ? 0.25 : 0.45;
    final pupilOffsetY = state == AssistantState.annoyed ? -2.0 : 0.0;

    if (eyeBlinkValue < 0.7) {
      final pupilSize = eyeWidth * pupilScale;
      final pupilRect = Rect.fromCenter(
        center: Offset(
          eyeX + offset.dx * 5,
          eyeY + offset.dy * 5 + pupilOffsetY,
        ),
        width: pupilSize,
        height: pupilSize * 1.1,
      );
      final pupilRRect = RRect.fromRectAndRadius(
        pupilRect,
        const Radius.circular(8),
      );

      // تدرج البؤبؤ للعمق
      final pupilPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            _lighten(pupilColor, 0.2),
            pupilColor,
            _darken(pupilColor, 0.3),
          ],
        ).createShader(pupilRect);
      canvas.drawRRect(pupilRRect, pupilPaint);

      // لمعة البؤبؤ الرئيسية - أكثر وضوحاً
      canvas.drawCircle(
        pupilRect.center.translate(-pupilSize * 0.25, -pupilSize * 0.25),
        pupilSize * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );

      // لمعة ثانوية صغيرة
      canvas.drawCircle(
        pupilRect.center.translate(pupilSize * 0.15, pupilSize * 0.1),
        pupilSize * 0.1,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    }

    // انعكاس ضوئي على العين (زجاجي) - أكثر وضوحاً
    if (eyeBlinkValue < 0.5) {
      final shinePath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              eyeRect.left + 4,
              eyeRect.top + 4,
              eyeWidth * 0.45,
              eyeHeight * 0.35,
            ),
            const Radius.circular(6),
          ),
        );

      canvas.drawPath(
        shinePath,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // جفون الانزعاج (Eyelids for Annoyed State)
    if (state == AssistantState.annoyed) {
      final eyelidPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;

      // جفن علوي مائل (غاضب)
      // نرسم مساراً مائلاً يبدأ من الأعلى وينزل نحو الأنف
      // يختلف الميلان حسب العين (يسار أو يمين)
      // eyeRect يحدد حدود العين الكاملة

      // نحدد اتجاه الميل بناءً على مركز العين بالنسبة لمركز الوجه
      // لكن هنا نعمل داخل _drawEye3D وهي ترسم عيناً واحدة.
      // نحتاج لمعرفة هل هي العين اليمنى أم اليسرى.
      // نمرر معامل 'sign' أو نستنتج من eyeRect.center.dx
      // ولكن الأسلم رسم شكل "V" مقلوب تقريباً لو كانت العينين قريبتين، أو ببساطة ميلان حاد.

      // لنفترض أننا نريد نظرة حادة "Angry Brows"
      // سنرسم مستطيلاً مائلاً أو Path مخصص

      // تحديث: المستخدم طلب تحسين التعبير، لذا سأستخدم Path بسيط مائل
      // سأعتمد على أن العيون عادة متناظرة، وسأرسم الجفن بحيث يغطي الجزء العلوي بشكل مائل.

      // رسم جفن "مستقيم" لكن نازل أكثر (60%) ليعطي نظرة "غير مبال" أو "منزعج جداً"
      canvas.drawRect(
        Rect.fromLTWH(
          eyeRect.left,
          eyeRect.top,
          eyeWidth,
          eyeHeight * 0.55, // تغطية 55%
        ),
        eyelidPaint,
      );

      // إضافة "حاجب" وهمي مائل فوق العين لزيادة الحدة
      final browPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // خط مائل فوق العين
      canvas.drawLine(
        Offset(eyeRect.left, eyeRect.top + eyeHeight * 0.2),
        Offset(eyeRect.right, eyeRect.top + eyeHeight * 0.1), // ميلان بسيط
        browPaint,
      );
    }
  }

  /// رسم الهوائي ثلاثي الأبعاد المحسّن
  void _drawAntenna3D(
    Canvas canvas,
    Offset center,
    double radius, [
    Color? color,
    double rotation = 0,
  ]) {
    // عمود الهوائي الرئيسي - أكثر سمكاً وبريقاً
    final antennaRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -radius * 0.95),
        width: 8, // زيادة العرض
        height: radius * 0.4, // زيادة الطول
      ),
      const Radius.circular(4),
    );

    // تدرج لوني متحرك للعمود
    final antennaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _lighten(antennaColor, 0.3),
          antennaColor,
          _darken(antennaColor, 0.2),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(antennaRect.outerRect);
    canvas.drawRRect(antennaRect, antennaPaint);

    // خطوط لامعة على العمود
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(-2, -radius * 0.95),
          width: 2,
          height: radius * 0.35,
        ),
        const Radius.circular(1),
      ),
      highlightPaint,
    );

    // كرة الهوائي العلوية - أكبر وأكثر بريقاً
    final ballCenter = Offset(center.dx, center.dy - radius * 1.3);
    final ballRadius = radius * 0.15; // زيادة الحجم

    // ظل الكرة
    final ballShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(ballCenter.dx + 2, ballCenter.dy + 3),
      ballRadius,
      ballShadow,
    );

    // موجات الراديو المتحركة (3 موجات)
    final waveTime = DateTime.now().millisecondsSinceEpoch / 1000;
    for (int i = 0; i < 3; i++) {
      final waveProgress = ((waveTime + i * 0.3) % 1.0);
      final waveRadius = ballRadius * (1.5 + waveProgress * 2);
      final waveAlpha = (1.0 - waveProgress) * 0.4;

      final wavePaint = Paint()
        ..color = antennaColor.withValues(alpha: waveAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(ballCenter, waveRadius, wavePaint);
    }

    // طبق الرادار الدوار (تحويله لحلقة تكنولوجية)
    canvas.save();
    canvas.translate(ballCenter.dx, ballCenter.dy);

    // زاوية الدوران المستمر
    final time = DateTime.now().millisecondsSinceEpoch / 500; // سرعة الدوران
    final angle = (rotation * 2 * math.pi) + time;

    // رسم الحامل
    final basePaint = Paint()
      ..color = _darken(antennaColor, 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 2), width: 6, height: 8),
        const Radius.circular(3),
      ),
      basePaint,
    );

    // الحلقة الدوارة (Orbiting Ring)
    // نستخدم التحويل المنظوري لرسم دائرة تبدو كأنها تدور في 3D
    final ringRadiusX = radius * 0.8;
    final ringRadiusY = radius * 0.25;

    // ميلان الحلقة يتحرك قليلاً
    final tilt = math.sin(time * 0.5) * 0.2;

    // رسم الحلقة الخلفية (النصف البعيد)
    final ringPath = Path();
    for (double i = 0; i <= math.pi; i += 0.1) {
      final x = math.cos(i + angle) * ringRadiusX;
      final y = math.sin(i + angle) * ringRadiusY + (math.sin(i) * tilt * 10);
      if (i == 0) {
        ringPath.moveTo(x, y);
      } else {
        ringPath.lineTo(x, y);
      }
    }

    final backRingPaint = Paint()
      ..color = _darken(antennaColor, 0.4).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(ringPath, backRingPaint);

    // رسم الجسم المركزي (Dish/Hub)
    final dishWidth = radius * 0.6;
    final dishHeight = radius * 0.18;
    final dishRect = Rect.fromCenter(
      center: const Offset(0, 4),
      width: dishWidth,
      height: dishHeight,
    );

    final dishPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          _lighten(antennaColor, 0.6),
          antennaColor,
          _darken(antennaColor, 0.1),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(dishRect);

    canvas.drawOval(dishRect, dishPaint);

    // حافة الطبق
    canvas.drawOval(
      dishRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // رسم الحلقة الأمامية (النصف القريب)
    final frontRingPath = Path();
    for (double i = math.pi; i <= 2 * math.pi; i += 0.1) {
      final x = math.cos(i + angle) * ringRadiusX;
      final y = math.sin(i + angle) * ringRadiusY + (math.sin(i) * tilt * 10);
      if (i == math.pi) {
        frontRingPath.moveTo(x, y);
      } else {
        frontRingPath.lineTo(x, y);
      }
    }

    // التوهج
    canvas.drawPath(
      frontRingPath,
      Paint()
        ..color = antennaColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // الحلقة الأساسية
    final frontRingPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          antennaColor.withValues(alpha: 0.1),
          Colors.white,
          antennaColor.withValues(alpha: 0.1),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: ringRadiusX))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(frontRingPath, frontRingPaint);

    // نقطة ضوء تدور على الحلقة
    final lightX = math.cos(angle + math.pi / 2) * ringRadiusX;
    final lightY =
        math.sin(angle + math.pi / 2) * ringRadiusY +
        (math.sin(math.pi / 2) * tilt * 10);

    canvas.drawCircle(
      Offset(lightX, lightY),
      3,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.restore();

    // الكرة المركزية النابضة
    final lightColor = state == AssistantState.thinking
        ? Colors.amber
        : (state == AssistantState.deleting || state == AssistantState.sad
              ? Colors.red
              : state == AssistantState.success ||
                    state == AssistantState.celebrate
              ? Colors.green
              : primaryColor);

    // نبض الضوء
    final pulseValue = 0.7 + (math.sin(waveTime * 4) * 0.3);

    // هالة الضوء
    final glowPaint = Paint()
      ..color = lightColor.withValues(alpha: 0.3 * pulseValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(ballCenter, ballRadius * 1.8, glowPaint);

    // الكرة نفسها بتدرج لوني
    final ballPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _lighten(lightColor, 0.4),
          lightColor,
          _darken(lightColor, 0.2),
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: ballCenter, radius: ballRadius));

    canvas.drawCircle(ballCenter, ballRadius, ballPaint);

    // لمعة على الكرة
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7 * pulseValue);
    canvas.drawCircle(
      Offset(
        ballCenter.dx - ballRadius * 0.3,
        ballCenter.dy - ballRadius * 0.3,
      ),
      ballRadius * 0.4,
      shinePaint,
    );
  }

  /// رسم الخدود - ألوان أكثر وضوحاً
  void _drawCheeks(Canvas canvas, Offset center, double radius) {
    // الخد الأيسر
    final leftCheekPos = Offset(
      center.dx - radius * 0.55,
      center.dy + radius * 0.2,
    );
    final leftCheekPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [cheeksColor.withValues(alpha: 0.55), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: leftCheekPos, radius: radius * 0.2),
          );

    canvas.drawCircle(leftCheekPos, radius * 0.16, leftCheekPaint);

    // الخد الأيمن
    final rightCheekPos = Offset(
      center.dx + radius * 0.55,
      center.dy + radius * 0.2,
    );
    final rightCheekPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [cheeksColor.withValues(alpha: 0.55), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: rightCheekPos, radius: radius * 0.2),
          );

    canvas.drawCircle(rightCheekPos, radius * 0.16, rightCheekPaint);
  }

  void _drawMouth(Canvas canvas, Offset center, double radius) {
    // إعدادات الرسم
    final mouthPaint = Paint()
      ..color = mouthColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // إعدادات الظل
    final mouthShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final mouthY = center.dy + radius * 0.25;
    final mouthWidth = radius * 0.4;
    final mouthPath = Path();

    // اختيار الشكل حسب الحالة
    if (state == AssistantState.happy ||
        state == AssistantState.excited ||
        state == AssistantState.greeting ||
        state == AssistantState.celebrate ||
        state == AssistantState.success) {
      // ابتسامة :)
      mouthPath.addArc(
        Rect.fromCenter(
          center: Offset(center.dx, mouthY),
          width: mouthWidth,
          height: radius * 0.25,
        ),
        0.1,
        3.14 - 0.2, // نصف دائرة لابتسامة عريضة
      );
    } else if (state == AssistantState.sad) {
      // حزن :(
      mouthPath.addArc(
        Rect.fromCenter(
          center: Offset(center.dx, mouthY + 10),
          width: mouthWidth,
          height: radius * 0.25,
        ),
        3.14 + 0.2, // قوس معكوس
        3.14 - 0.4,
      );
    } else if (state == AssistantState.annoyed) {
      // انزعاج (خط متعرج - ZigZag)
      final startX = center.dx - mouthWidth * 0.5;
      final step = mouthWidth * 0.25; // 4 segments

      mouthPath.moveTo(startX, mouthY);
      mouthPath.lineTo(startX + step, mouthY - 4);
      mouthPath.lineTo(startX + step * 2, mouthY + 4);
      mouthPath.lineTo(startX + step * 3, mouthY - 4);
      mouthPath.lineTo(startX + step * 4, mouthY);
    } else if (state == AssistantState.thinking) {
      // تفكير (خط مستقيم صغير)
      mouthPath.moveTo(center.dx - mouthWidth * 0.3, mouthY);
      mouthPath.lineTo(center.dx + mouthWidth * 0.3, mouthY);
    } else {
      // حياد (خط منحني بسيط)
      mouthPath.moveTo(center.dx - mouthWidth * 0.4, mouthY);
      mouthPath.quadraticBezierTo(
        center.dx,
        mouthY + 5,
        center.dx + mouthWidth * 0.4,
        mouthY,
      );
    }

    // رسم الظل والفم
    canvas.drawPath(mouthPath, mouthShadow);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  /// تفتيح اللون
  Color _lighten(Color color, double amount) {
    return Color.fromARGB(
      color.a.toInt(),
      (color.r + (255 - color.r) * amount).round().clamp(0, 255),
      (color.g + (255 - color.g) * amount).round().clamp(0, 255),
      (color.b + (255 - color.b) * amount).round().clamp(0, 255),
    );
  }

  /// تعتيم اللون
  Color _darken(Color color, double amount) {
    return Color.fromARGB(
      color.a.toInt(),
      (color.r * (1 - amount)).round().clamp(0, 255),
      (color.g * (1 - amount)).round().clamp(0, 255),
      (color.b * (1 - amount)).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(RobotPainter oldDelegate) {
    return oldDelegate.eyeBlinkValue != eyeBlinkValue ||
        oldDelegate.eyeOffset != eyeOffset ||
        oldDelegate.state != state ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.eyesColor != eyesColor ||
        oldDelegate.eyesRimColor != eyesRimColor ||
        oldDelegate.eyesBgColor != eyesBgColor ||
        oldDelegate.faceColor != faceColor ||
        oldDelegate.mouthColor != mouthColor ||
        oldDelegate.antennaColor != antennaColor ||
        oldDelegate.cheeksColor != cheeksColor ||
        oldDelegate.radarRotation != radarRotation;
  }
}

class RobotEarsPainter extends CustomPainter {
  final Color primaryColor;
  final Color earsColor;

  RobotEarsPainter({required this.primaryColor, required this.earsColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // إعداد الحدود الزجاجية البيضاء
    final glassBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);

    // دالة مساعدة لرسم شكل الأذن المدبب (طراز خفاشي)
    Path buildEarPath(Offset earCenter, double w, double h, bool isLeft) {
      final path = Path();
      // ميلان للأذنين لتشبه الخفاش (زاوية للخارج)
      final tilt = isLeft ? -0.3 : 0.3; // إزاحة أفقية للقمة

      // نبدأ من الأسفل في المنتصف
      path.moveTo(earCenter.dx, earCenter.dy + h * 0.4);

      // منحنى للجانب الخارجي (محدب للخارج كثيراً)
      path.quadraticBezierTo(
        earCenter.dx + (isLeft ? -w * 1.5 : w * 1.5), // Control point far out
        earCenter.dy + h * 0.1, // Lower control point
        earCenter.dx +
            (isLeft ? -w * 0.8 : w * 0.8) +
            tilt * w, // Tip x (angled out)
        earCenter.dy - h * 0.8, // Tip y (very high)
      );

      // منحنى للجانب الداخلي (مقعر للداخل)
      path.quadraticBezierTo(
        earCenter.dx + (isLeft ? w * 0.2 : -w * 0.2), // Control point inside
        earCenter.dy - h * 0.3,
        earCenter.dx +
            (isLeft ? w * 0.4 : -w * 0.4), // Base inner point (wide base)
        earCenter.dy + h * 0.4,
      );

      path.close();
      return path;
    }

    // === الأذن اليسرى ===
    // رفع الأذن للأعلى وزيادة الحجم
    final leftEarW = radius * 0.55; // أعرض
    final leftEarH = radius * 1.3; // أطول
    // رفع الموضع (-radius * 0.5 بدلاً من 0.3)
    final leftEarCenter = center.translate(-radius * 0.8, -radius * 0.5);

    final leftEarPath = buildEarPath(leftEarCenter, leftEarW, leftEarH, true);

    // تدرج أسود زجاجي للأذن
    final leftEarPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.95),
            ],
            stops: const [0.2, 0.5, 1.0],
          ).createShader(
            Rect.fromCenter(
              center: leftEarCenter,
              width: leftEarW,
              height: leftEarH,
            ),
          )
      ..style = PaintingStyle.fill;

    canvas.drawPath(leftEarPath, leftEarPaint);

    // الحدود الزجاجية
    canvas.drawPath(leftEarPath, glassBorderPaint);

    // تفاصيل داخلية للأذن اليسرى (أزرق غامق)
    // رسم مسار داخلي أصغر
    final leftInnerPath = buildEarPath(
      leftEarCenter,
      leftEarW * 0.6,
      leftEarH * 0.7,
      true,
    );
    // إزاحة بسيطة للداخل وللأعلى
    final leftInnerPathShifted = leftInnerPath.shift(
      Offset(0, leftEarH * 0.05),
    );

    canvas.drawPath(
      leftInnerPathShifted,
      Paint()
        ..color = earsColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );

    // === الأذن اليمنى ===
    final rightEarW = radius * 0.55;
    final rightEarH = radius * 1.3;
    final rightEarCenter = center.translate(radius * 0.8, -radius * 0.5);

    final rightEarPath = buildEarPath(
      rightEarCenter,
      rightEarW,
      rightEarH,
      false,
    );

    // تدرج أسود زجاجي
    final rightEarPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.95),
            ],
            stops: const [0.2, 0.5, 1.0],
          ).createShader(
            Rect.fromCenter(
              center: rightEarCenter,
              width: rightEarW,
              height: rightEarH,
            ),
          )
      ..style = PaintingStyle.fill;

    canvas.drawPath(rightEarPath, rightEarPaint);

    // الحدود الزجاجية
    canvas.drawPath(rightEarPath, glassBorderPaint);

    // تفاصيل داخلية للأذن اليمنى (أزرق غامق)
    final rightInnerPath = buildEarPath(
      rightEarCenter,
      rightEarW * 0.6,
      rightEarH * 0.7,
      false,
    );
    final rightInnerPathShifted = rightInnerPath.shift(
      Offset(0, rightEarH * 0.05),
    );

    canvas.drawPath(
      rightInnerPathShifted,
      Paint()
        ..color = earsColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(RobotEarsPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.earsColor != earsColor;
}

class RobotPlatformPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  RobotPlatformPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // تصميم هولوغرافيكي جديد (New Holographic Design)

    // 1. الحلقة الخارجية الدوارة (Outer Rotating Ring)
    // نستخدم animationValue لتدويرها
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animationValue * 2 * math.pi); // دوران كامل
    canvas.translate(-center.dx, -center.dy);

    canvas.restore();

    // بدلاً من تدوير الكانفاس المشوه (لأنه بيضاوي)، سنرسم أقواس متدرجة
    final ringRect = Rect.fromCenter(
      center: center,
      width: maxRadius * 2.0,
      height: maxRadius * 0.7,
    );

    // الحلقة الأساسية
    final baseRingPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(ringRect, baseRingPaint);

    // حلقات متداخلة (Scanning Rings)
    for (int i = 1; i <= 3; i++) {
      final scale = 1.0 - (i * 0.2);
      // زيادة الشفافية بشكل كبير لتظهر في الوضع الداكن
      final opacity = 0.8 - (i * 0.15); // Increased from 0.5
      final subRect = Rect.fromCenter(
        center: center,
        width: ringRect.width * scale,
        height: ringRect.height * scale,
      );
      canvas.drawOval(
        subRect,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth =
              2.0 // Increased from 1.5
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            1.0,
          ), // Added slight glow
      );
    }

    // قلب مشع (Radiant Core)
    final coreGradient =
        RadialGradient(
          colors: [
            color.withValues(alpha: 0.9), // Increased from 0.6
            color.withValues(alpha: 0.2), // Increased from 0.0
          ],
        ).createShader(
          Rect.fromCenter(
            center: center,
            width: maxRadius,
            height: maxRadius * 0.5,
          ),
        );

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: maxRadius * 1.2,
        height: maxRadius * 0.5,
      ),
      Paint()..shader = coreGradient,
    );

    // خطوط ليزر ماسحة (Scanner Lines)
    // تتحرك ذهاباً وإياباً بناءً على animationValue
    // animationValue 0..1
    // scanOffset goes -width/2 to width/2
    final scanX = (animationValue - 0.5) * ringRect.width;

    final scannerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // نرسم خط عمودي لكن داخل البيضاوي (Clip)
    // للتبسيط سنرسم خط قصير
    canvas.save();
    // Clip path to oval
    canvas.clipPath(Path()..addOval(ringRect));

    canvas.drawLine(
      Offset(center.dx + scanX, center.dy - ringRect.height / 2),
      Offset(center.dx + scanX, center.dy + ringRect.height / 2),
      scannerPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RobotPlatformPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        color != oldDelegate.color;
  }
}

/// Alias
class AssistantCharacterSimple extends AssistantCharacter {
  const AssistantCharacterSimple({super.key, super.size});
}
