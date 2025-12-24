import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/robot_settings_service.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/voice_chat_screen.dart';
import 'screens/calculator_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/task_provider.dart';
import 'providers/note_provider.dart';
import 'utils/app_theme.dart';
import 'widgets/global_assistant_wrapper.dart';
import 'services/sound_service.dart';
import 'services/background_service.dart';
import 'services/font_service.dart';
import 'services/gemini_service.dart';
import 'services/assistant_service.dart';
import 'services/avatar_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/tts_service.dart';
import 'services/openrouter_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop platforms only
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } catch (e) {
    debugPrint('Platform check error: $e');
  }

  // تحميل الإعدادات بالتوازي لتسريع وقت البدء
  try {
    await Future.wait([
      SoundService.loadSettings(),
      BackgroundService.loadSettings(),
      FontService.loadSettings(),
      RobotSettingsService.loadSettings(),
      AvatarService.loadSettings(),
      AlarmService().loadSettings(),
      AssistantService().loadUserName(),
      OpenRouterService.loadModels(),
    ]);
  } catch (e) {
    debugPrint('Error during parallel service initialization: $e');
  }

  // تهيئة الإشعارات و Gemini (قد تعتمد على بعض الإعدادات أو تتطلب ترتيباً خاصاً)
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService error: $e');
  }

  try {
    await GeminiService.initialize();
  } catch (e) {
    debugPrint('GeminiService error: $e');
  }

  // تهيئة خدمة النطق (TTS) - تشغيلها في الخلفية لضمان عدم تأخير تشغيل التطبيق
  TtsService.initialize().catchError((e) {
    debugPrint('TtsService background init error: $e');
  });

  runApp(const PersonalAssistantApp());
}

// مفتاح عام للـ Navigator للوصول إليه من أي مكان
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AppRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateHomeStatus(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateHomeStatus(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateHomeStatus(newRoute);
    }
  }

  void _updateHomeStatus(Route<dynamic> route) {
    final name = route.settings.name;
    // نعتبر الشاشة الرئيسية هي /home فقط
    final isHome = name == '/home';
    AssistantService().setIsAtHome(isHome);

    // إخفاء الروبوت تماماً في شاشات البداية والتهيئة والحاسبة
    // نعتبر '/' هي شاشة البداية (Splash)
    final isExcluded =
        name == '/onboarding' ||
        name == null ||
        name == '/' ||
        name == 'initial_splash' ||
        name == '/calculator';
    AssistantService().setIsCurrentRouteAllowed(!isExcluded);
  }
}

class PersonalAssistantApp extends StatelessWidget {
  const PersonalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            scaffoldMessengerKey: scaffoldMessengerKey,
            navigatorKey: navigatorKey,
            navigatorObservers: [AppRouteObserver()],
            title: 'مذكرة الحياة',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(themeProvider.currentTheme),
            // Support RTL for Arabic
            locale: const Locale('ar', 'SA'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: GlobalAssistantWrapper(child: child!),
              );
            },
            // المسارات
            routes: {
              '/home': (context) => const HomeScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/voice-chat': (context) => const VoiceChatScreen(),
              '/calculator': (context) => const CalculatorScreen(),
            },
            home: const SplashScreen(key: ValueKey('initial_splash')),
          );
        },
      ),
    );
  }
}
