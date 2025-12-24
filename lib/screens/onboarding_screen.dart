import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../services/sound_service.dart';
import '../services/assistant_customization_service.dart';
import '../services/gemini_service.dart';
import '../services/assistant_service.dart';
import '../utils/app_snackbar.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _assistantNameController =
      TextEditingController();

  int _currentPage = 0;
  String _selectedGender = 'male';
  String _selectedPersonality = 'default';

  // Animation Controllers
  late AnimationController _bgController;
  late Animation<Color?> _bgColor1;
  late Animation<Color?> _bgColor2;

  late AnimationController _contentController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Background Animation
    _bgController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _bgColor1 = ColorTween(
      begin: const Color(0xFF1A1A2E), // Dark Blue
      end: const Color(0xFF16213E), // Slightly lighter
    ).animate(_bgController);

    _bgColor2 = ColorTween(
      begin: const Color(0xFF0F3460), // Accent Blue
      end: const Color(0xFF533483), // Purple Accent
    ).animate(_bgController);

    // Content Entrance Animation
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic,
          ),
        );

    _contentController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _assistantNameController.dispose();
    _bgController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _contentController.reset();
    _contentController.forward();
  }

  void _nextPage() {
    SoundService.playClick();
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut, // Corrected curve
      );
    }
  }

  void _previousPage() {
    SoundService.playClick();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (_nameController.text.trim().isEmpty) {
      SoundService.playError();
      AppSnackBar.error(context, 'الرجاء إدخال اسمك لنبدأ الرحلة!');
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      return;
    }

    SoundService.playSuccess();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    await UserService.saveUserData(
      name: _nameController.text.trim(),
      gender: _selectedGender,
    );

    await AssistantCustomizationService.setAssistantName(
      _assistantNameController.text.trim(),
    );
    await AssistantCustomizationService.setAssistantPersonality(
      _selectedPersonality,
    );

    await GeminiService.initialize();
    await AssistantService().loadUserName();
    AssistantService().setIsOnboardingComplete(true);

    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss loading
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent background squeeze
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _bgColor1.value ?? Colors.black,
                  _bgColor2.value ?? Colors.blue,
                  _bgColor1.value ?? Colors.black,
                ],
              ),
            ),
            child: Stack(
              children: [
                // ambient circles
                Positioned(
                  top: -100,
                  right: -100,
                  child: _buildBlurCircle(
                    200,
                    Colors.purple.withValues(alpha: 0.3),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: -50,
                  child: _buildBlurCircle(
                    250,
                    Colors.blue.withValues(alpha: 0.2),
                  ),
                ),

                SafeArea(
                  child: Column(
                    children: [
                      // Header / Progress
                      _buildHeaderProgress(),

                      // Main Content
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics:
                              const NeverScrollableScrollPhysics(), // Disable swipe to force flow
                          onPageChanged: _onPageChanged,
                          children: [
                            _buildWelcomePage(),
                            _buildNamePage(),
                            _buildGenderPage(),
                            _buildAssistantPage(),
                            _buildReadyPage(),
                          ],
                        ),
                      ),

                      // Footer Navigation
                      _buildFooterNavigation(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeaderProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(4),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooterNavigation() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          if (_currentPage > 0)
            TextButton.icon(
              onPressed: _previousPage,
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white70,
                size: 18,
              ),
              label: const Text(
                'السابق',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
              ),
            )
          else
            const SizedBox(width: 80),

          // Next Button (Premium Pill)
          GestureDetector(
            onTap: _currentPage == 4 ? _completeOnboarding : _nextPage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.purpleAccent],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentPage == 4 ? 'ابدأ الرحلة' : 'التالي',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentPage == 4
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Pages ---

  Widget _buildAnimatedContent({required Widget child}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: child),
    );
  }

  Widget _buildWelcomePage() {
    return _buildAnimatedContent(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Logo Container
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // outer rotating glow
                RotationTransition(
                  turns: _bgController,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.cyanAccent.withValues(alpha: 0.0),
                          Colors.blueAccent.withValues(alpha: 0.5),
                          Colors.purpleAccent.withValues(alpha: 0.3),
                          Colors.cyanAccent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // floating logo
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOutSine,
                  builder: (context, value, child) {
                    final offset =
                        math.sin(DateTime.now().millisecondsSinceEpoch / 1000) *
                        10;
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.white10,
                          child: const Icon(
                            Icons.smart_toy,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          const Text(
            'مرحباً بك في',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 24,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 10),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Colors.blueAccent,
                Colors.purpleAccent,
                Colors.pinkAccent,
              ],
            ).createShader(bounds),
            child: const Text(
              'مذكرة الحياة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'رفيقك الذكي لتنظيم يومك، تحقيق أهدافك،\nوالتحدث بذكاء.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNamePage() {
    return _buildAnimatedContent(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'لنبدأ بالتعارف',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'ما هو اسمك؟',
              style: TextStyle(color: Colors.white60, fontSize: 18),
            ),
            const SizedBox(height: 50),

            // Glass Text Field
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    cursorColor: Colors.cyanAccent,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'اكتب اسمك هنا',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      icon: const Icon(Icons.person_pin, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderPage() {
    return _buildAnimatedContent(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'كيف تحب أن نخاطبك؟',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGenderCard('male', 'ذكر', Icons.male),
                const SizedBox(width: 20),
                _buildGenderCard('female', 'أنثى', Icons.female),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantPage() {
    return _buildAnimatedContent(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, size: 60, color: Colors.purpleAccent),
            const SizedBox(height: 20),
            const Text(
              'صمم مساعدك',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'اختر شخصية واسماً لمساعدك الذكي',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 40),

            // Assistant Name Input
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _assistantNameController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                          cursorColor: Colors.purpleAccent,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'اسم المساعد (اختياري)',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                          ),
                        ),
                      ),
                      Container(height: 60, width: 1, color: Colors.white24),
                      IconButton(
                        onPressed: () {
                          SoundService.playClick();
                          setState(() {
                            _assistantNameController.text =
                                AssistantCustomizationService.getRandomIraqiName();
                          });
                        },
                        icon: const Icon(
                          Icons.casino_rounded,
                          color: Colors.purpleAccent,
                        ),
                        tooltip: 'اقتراح اسم عراقي',
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Personality Selection
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'شخصية المساعد:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildPersonalityChip('default', '🤖 افتراضي', Colors.grey),
                _buildPersonalityChip('friendly', '😊 ودود', Colors.orange),
                _buildPersonalityChip('formal', '👔 رسمي', Colors.blue),
                _buildPersonalityChip('wise', '🧙 حكيم', Colors.purple),
                _buildPersonalityChip('energetic', '⚡ نشيط', Colors.yellow),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyPage() {
    final greeting = _selectedGender == 'female' ? 'سيدة' : 'سيد';
    final name = _nameController.text.trim();

    return _buildAnimatedContent(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.greenAccent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Text(
              'أهلاً بك يا $greeting $name!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'كل شيء جاهز.\nاستمتع بتجربة فريدة مع مساعدك الذكي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildGenderCard(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () {
        SoundService.playClick();
        setState(() => _selectedGender = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 130,
        height: 160,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white24,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 50,
              color: isSelected ? const Color(0xFF1A1A2E) : Colors.white,
            ),
            const SizedBox(height: 15),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1A1A2E) : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalityChip(String value, String label, Color color) {
    final isSelected = _selectedPersonality == value;
    return GestureDetector(
      onTap: () {
        SoundService.playClick();
        setState(() => _selectedPersonality = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color.withValues(alpha: 1) : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
