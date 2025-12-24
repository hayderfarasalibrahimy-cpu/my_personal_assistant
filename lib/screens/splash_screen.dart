import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/note_provider.dart';
import '../services/user_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // المتحكم الرئيسي
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // متحكم النبض
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // متحكم الدوران للهالة
    _rotateController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();

    // Load data with error handling
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait for minimum splash duration
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      // Try to load data, but don't block if it fails
      try {
        await Future.wait([
          Provider.of<TaskProvider>(context, listen: false).loadTasks(),
          Provider.of<NoteProvider>(context, listen: false).loadNotes(),
        ], eagerError: true);
      } catch (e) {
        debugPrint('Error loading data: $e');
        // Continue anyway - data will load later
      }

      if (!mounted) return;

      // التحقق من أول تشغيل
      final isFirstLaunch = await UserService.isFirstLaunch();

      if (!mounted) return;

      if (isFirstLaunch) {
        // أول تشغيل - اذهب إلى شاشة الترحيب
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const OnboardingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        // ليس أول تشغيل - اذهب إلى الشاشة الرئيسية
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            settings: const RouteSettings(name: '/home'),
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      debugPrint('Critical error in splash: $e');
      // Still try to navigate
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/home'),
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e), // أزرق داكن
              Color(0xFF16213e), // نيلي
              Color(0xFF0f3460), // أزرق عميق
              Color(0xFF1a1a2e), // أزرق داكن
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // خلفية النجوم المتحركة
            ...List.generate(20, (index) => _buildStar(index)),

            // المحتوى الرئيسي
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _mainController,
                  _pulseController,
                  _rotateController,
                ]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // الأيقونة مع التأثيرات
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // الهالة الخارجية المتحركة
                            Transform.rotate(
                              angle: _rotateController.value * 2 * math.pi,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      const Color(
                                        0xFF6a1b9a,
                                      ).withValues(alpha: 0.0),
                                      const Color(
                                        0xFF2196f3,
                                      ).withValues(alpha: 0.3),
                                      const Color(
                                        0xFF00bcd4,
                                      ).withValues(alpha: 0.5),
                                      const Color(
                                        0xFF6a1b9a,
                                      ).withValues(alpha: 0.3),
                                      const Color(
                                        0xFF6a1b9a,
                                      ).withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // التوهج الداخلي
                            Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2196f3,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00bcd4,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 50,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // الأيقونة الفعلية
                            Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/app_icon.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback إذا لم تتوفر الأيقونة
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF6a1b9a),
                                              Color(0xFF2196f3),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.smart_toy,
                                          size: 50,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // اسم التطبيق
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF00bcd4),
                                Color(0xFFffffff),
                                Color(0xFF2196f3),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'مذكرة الحياة',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // الوصف
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 0.7),
                          child: Text(
                            'مساعدك الذكي لتنظيم حياتك',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // شريط التحميل المحسن
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 0.5),
                          child: SizedBox(
                            width: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00bcd4),
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // رسالة المطور
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 0.3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'تم التطوير بواسطة',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'حيدر فراس',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.favorite,
                                      color: Colors.red.shade400,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'نسألكم الدعاء',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontStyle: FontStyle.italic,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
      ),
    );
  }

  // بناء نجمة متلألئة
  Widget _buildStar(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 3 + 1;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * MediaQuery.of(context).size.height;
    final delay = random.nextDouble() * 2;

    return Positioned(
      left: left,
      top: top,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: (2000 + delay * 1000).toInt()),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: (math.sin(value * math.pi * 2 + delay) + 1) / 2 * 0.7,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: size * 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
