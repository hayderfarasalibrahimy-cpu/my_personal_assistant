import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/note_provider.dart';
import '../models/task.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/speed_dial_fab.dart';
import '../widgets/vault_card.dart';
import '../utils/search_delegates.dart';
import '../services/sound_service.dart';
import '../services/toast_service.dart';
import '../services/background_service.dart';
import '../services/assistant_service.dart';
import '../services/robot_settings_service.dart';
import '../services/api_key_service.dart';
import '../services/user_service.dart';
import '../services/assistant_customization_service.dart';

import 'package:url_launcher/url_launcher.dart';

import 'tasks_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'add_task_screen.dart';
import 'add_note_screen.dart';
import 'chat_screen.dart';
import 'voice_chat_screen.dart';
import 'trash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const _HomeTab(),
    const TasksScreen(),
    const NotesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgWidget = BackgroundService.getBackgroundWidget(isDarkMode: isDark);

    return Scaffold(
      body: SelectionArea(
        child: Stack(
          children: [
            if (bgWidget != null) Positioned.fill(child: bgWidget),
            _selectedIndex == 0
                ? _HomeTab(
                    onNavigateToTasks: () {
                      setState(() => _selectedIndex = 1);
                    },
                  )
                : _screens[_selectedIndex],
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0 ? _buildFAB(context) : null,
      bottomNavigationBar: BackgroundService.hasBackground()
          ? ClipRRect(
              child: GlassContainer(
                blur: 15,
                opacity: 0.15,
                borderRadius: BorderRadius.zero,
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    height: 55, // زيادة الطول قليلاً لمنع استقطاع النصوص
                    indicatorColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    labelTextStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return IconThemeData(
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        );
                      }
                      return const IconThemeData(size: 16);
                    }),
                  ),
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'الرئيسية',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.task_outlined),
                        selectedIcon: Icon(Icons.task),
                        label: 'المهام',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.note_outlined),
                        selectedIcon: Icon(Icons.note),
                        label: 'الملاحظات',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: 'الإعدادات',
                      ),
                    ],
                  ),
                ),
              ),
            )
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 55, // زيادة الطول قليلاً لمنع استقطاع النصوص
                labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                ),
                indicatorColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    );
                  }
                  return const IconThemeData(size: 16);
                }),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'الرئيسية',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.task_outlined),
                    selectedIcon: Icon(Icons.task),
                    label: 'المهام',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.note_outlined),
                    selectedIcon: Icon(Icons.note),
                    label: 'الملاحظات',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'الإعدادات',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return AnimatedSpeedDial(
      mainIcon: const Icon(Icons.add, size: 18),
      backgroundColor: Theme.of(context).colorScheme.primary,
      children: [
        SpeedDialChild(
          icon: const Icon(Icons.task_alt, size: 18),
          label: 'مهمة جديدة',
          backgroundColor: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddTaskScreen()),
            );
          },
        ),
        SpeedDialChild(
          icon: const Icon(Icons.note_add, size: 18),
          label: 'ملاحظة جديدة',
          backgroundColor: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddNoteScreen()),
            );
          },
        ),
        SpeedDialChild(
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: 'الدردشة',
          backgroundColor: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          },
        ),
        SpeedDialChild(
          icon: const Icon(Icons.mic, size: 18),
          label: 'المساعد الصوتي',
          backgroundColor: Colors.red,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VoiceChatScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToTasks;

  const _HomeTab({this.onNavigateToTasks});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  void initState() {
    super.initState();

    // الاستماع لتغييرات إعدادات الروبوت (مثل الإخفاء/الإظهار)
    RobotSettingsNotifier().addListener(_onRobotSettingsChanged);

    // تحميل بيانات الترحيب المخصص
    _loadGreetingData();

    // عرض رسالة ترحيب من الروبوت بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && RobotSettingsService.isVisible) {
        AssistantService().greet();
      }
    });

    // إعلام المساعد بأننا في الشاشة الرئيسية
    AssistantService().setIsAtHome(true);

    // بدء الحوار العشوائي للروبوت
    if (RobotSettingsService.isVisible) {
      AssistantService().startMonologue();
    }
  }

  @override
  void dispose() {
    // إعلام المساعد بأننا غادرنا الشاشة الرئيسية
    AssistantService().setIsAtHome(false);

    RobotSettingsNotifier().removeListener(_onRobotSettingsChanged);
    // إيقاف الحوار عند الخروج
    AssistantService().stopMonologue();
    super.dispose();
  }

  String _userName = '';
  String _assistantName = 'المساعد الذكي';
  String _userTitle = '';

  Future<void> _loadGreetingData() async {
    final uName = await UserService.getUserName();
    final gender = await UserService.getUserGender();
    await AssistantCustomizationService.loadSettings();
    final aName = AssistantCustomizationService.getDisplayName();

    if (mounted) {
      setState(() {
        _userName = uName.isNotEmpty ? uName : 'صديقي';
        _userTitle = gender == 'female' ? 'سيدة' : 'سيد';
        _assistantName = aName;
      });
    }
  }

  void _onRobotSettingsChanged() {
    if (mounted) setState(() {});

    // تحديث حالة الحوار بناءً على الظهور
    if (RobotSettingsService.isVisible) {
      AssistantService().startMonologue();
    } else {
      AssistantService().stopMonologue();
    }
  }

  void _showDhikrDetailsDialog() {
    SoundService.playClick();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'فَضْلُ الذِّكْرِ',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'قول "بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم" هو دعاء عظيم لحفظ النفس والمال من البلاء، يقي من المفاجآت السيئة، ويُقال ثلاث مرات صباحًا ومساءً، حيث يضمن لمن يقولها الأمان من الأذى والداء بإذن الله تعالى، وتأكيدًا على استجابة الله لدعاء عباده.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'الفوائد والأحكام:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Text(
                '• الحماية من البلاء: يُقال إن من قالها صباحًا لم يفاجئه بلاء حتى يمسي، ومن قالها مساءً لم يفاجئه بلاء حتى يصبح، وهي للحفظ من شرور الدنيا والآخرة.',
                textAlign: TextAlign.center,
              ),
              const Text(
                '• سبب للشفاء: روي أنه من اشتكى ألمًا فليستعذ بالله وبقدرته، حيث أن اسم الله لا يضر معه شيء.',
                textAlign: TextAlign.center,
              ),
              const Text(
                '• ذكر إلهي: الدعاء يذكر العبد بربّه، ويعزّز ارتباطه به، ويُشعر بالسكينة والطمأنينة، لأن الله هو السميع لأقوال العباد والعليم بأفعالهم.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'كيفية الاستخدام:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text(
                'يُستحب أن تقال ثلاث مرات في الصباح وثلاث مرات في المساء، كما أرشد النبي (صلى الله عليه وآله).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'بشكل مختصر، الدعاء هو تعوذ بالله من كل مكروه، وتوكّل عليه، واعتراف بقدرته المطلقة.',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showStatDetailDialog(
    BuildContext context,
    String title,
    String value,
    String description,
    IconData icon,
    Color color,
  ) {
    SoundService.playClick();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context,
    IconData icon,
    String value,
    Color color,
    String tooltip, {
    required String description,
    required String title,
  }) {
    return InkWell(
      onTap: () => _showStatDetailDialog(
        context,
        title,
        value,
        description,
        icon,
        color,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Tooltip(
          message: tooltip,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDhikrBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: GestureDetector(
        onTap: _showDhikrDetailsDialog,
        child: SizedBox(
          width: double.infinity,
          child: GlassContainer(
            padding: const EdgeInsets.all(12),
            blur: 10,
            opacity: 0.1,
            borderRadius: BorderRadius.circular(16),
            child: const Column(
              children: [
                Text(
                  'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'انقر لمعرفة الفضل والفوائد',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final pendingTasks = taskProvider.pendingTasks;
        final completedToday = taskProvider.completedTasks
            .where(
              (t) =>
                  t.completedAt != null &&
                  t.completedAt!.day == DateTime.now().day,
            )
            .length;

        return SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 6),
                  // أزرار البحث والحاسبة والسلة ممركزة ومصغرة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        icon: Icons.calculate_outlined,
                        tooltip: 'الآلة الحاسبة',
                        onPressed: () {
                          SoundService.playClick();
                          Navigator.pushNamed(context, '/calculator');
                        },
                      ),
                      _ActionButton(
                        icon: Icons.delete_outline,
                        tooltip: 'سلة المحذوفات',
                        onPressed: () {
                          SoundService.playClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TrashScreen(),
                            ),
                          );
                        },
                      ),
                      _ActionButton(
                        icon: Icons.search,
                        tooltip: 'بحث',
                        onPressed: () {
                          SoundService.playClick();
                          final tasks = Provider.of<TaskProvider>(
                            context,
                            listen: false,
                          ).tasks;
                          final notes = Provider.of<NoteProvider>(
                            context,
                            listen: false,
                          ).notes;
                          showSearch(
                            context: context,
                            delegate: GlobalSearchDelegate(
                              tasks: tasks,
                              notes: notes,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: VaultCard(),
                  ),
                  const SizedBox(height: 8),
                  _buildDhikrBanner(),
                  const SizedBox(height: 4),

                  // Row for Welcome Card and AI Quota Card Side-by-Side
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Welcome Card (Restored & Personalized & Centered)
                          Expanded(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(8),
                              blur: 10,
                              opacity: 0.1,
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Hero(
                                      tag: 'robot_avatar',
                                      child: Icon(
                                        Icons.face_retouching_natural,
                                        size: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'أهلاً بك يا $_userTitle $_userName',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'أنا مساعدك $_assistantName',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Expanded(
                                    child: Consumer<NoteProvider>(
                                      builder: (context, noteProvider, _) {
                                        final completedCount =
                                            taskProvider.completedTasks.length;
                                        final pendingCount =
                                            taskProvider.pendingTasks.length;
                                        final totalTasks =
                                            completedCount + pendingCount;

                                        // 1. Completion Rate
                                        final completionRate = totalTasks == 0
                                            ? 0
                                            : ((completedCount / totalTasks) *
                                                      100)
                                                  .toInt();

                                        // 2. Urgent Tasks (High + Critical)
                                        final urgentCount = taskProvider
                                            .pendingTasks
                                            .where(
                                              (t) =>
                                                  t.priority ==
                                                      TaskPriority.high ||
                                                  t.priority ==
                                                      TaskPriority.critical,
                                            )
                                            .length;

                                        return Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                            horizontal: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              _buildMiniStat(
                                                context,
                                                Icons.pie_chart_outline,
                                                '%$completionRate',
                                                Colors.purple,
                                                'نسبة الإنجاز',
                                                title: 'نسبة الإنتاجية',
                                                description:
                                                    'هذه النسبة تمثل كفاءتك العامة في إنجاز المهام. يتم حسابها بناءً على عدد المهام المكتملة مقارنةً بالعدد الكلي للمهام.',
                                              ),
                                              _buildMiniStat(
                                                context,
                                                Icons.emoji_events_outlined,
                                                '$completedCount',
                                                Colors.amber,
                                                'إجمالي المنجز',
                                                title: 'سجل الإنجازات',
                                                description:
                                                    'مجموع كل المهام التي قمت بإتمامها بنجاح منذ بداية استخدامك للمساعد الشخصي.',
                                              ),
                                              _buildMiniStat(
                                                context,
                                                Icons.priority_high_rounded,
                                                '$urgentCount',
                                                Colors.red,
                                                'مهام عاجلة',
                                                title: 'مهام عاجلة',
                                                description:
                                                    'عدد المهام التي تتطلب انتباهاً فورياً (ذات أولوية عالية أو حرجة) ولم يتم إنجازها بعد.',
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
                          ),
                          const SizedBox(width: 8),
                          // 2. AI Quota Card (Reorganized to prevent clipping)
                          Expanded(
                            child: GlassContainer(
                              blur: 10,
                              opacity: 0.1,
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Center(
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              // Header - Title & Badge
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'ذكاء اصطناعي',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        ApiKeyService
                                                            .activeModel,
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),

                                              // Models Grid
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: Wrap(
                                                    spacing: 2,
                                                    runSpacing: 2,
                                                    alignment:
                                                        WrapAlignment.center,
                                                    children: [
                                                      _buildModelIndicator(
                                                        context,
                                                        'Gemini',
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                        ApiKeyService
                                                                .activeModel ==
                                                            'Gemini',
                                                        'نموذج Google الأساسي للأداء العالي وتعدد الوسائط.',
                                                      ),
                                                      _buildModelIndicator(
                                                        context,
                                                        'DeepSeek R1',
                                                        Colors.blue.shade300,
                                                        ApiKeyService
                                                                .activeModel ==
                                                            'DeepSeek R1',
                                                        'نموذج صيني متفوق في البرمجة والمنطق الرياضي.',
                                                      ),
                                                      _buildModelIndicator(
                                                        context,
                                                        'Mistral Devstral',
                                                        Colors.orange.shade300,
                                                        ApiKeyService
                                                            .activeModel
                                                            .contains(
                                                              'Mistral',
                                                            ),
                                                        'نموذج Mistral الأحدث والأكثر ذكاءً للمهام البرمجية والعامة.',
                                                      ),
                                                      _buildModelIndicator(
                                                        context,
                                                        'Llama 3.3 70B',
                                                        Colors
                                                            .blueGrey
                                                            .shade300,
                                                        ApiKeyService
                                                            .activeModel
                                                            .contains('Llama'),
                                                        'نموذج Meta الأحدث والأقوى، ممتاز في التحليل والكتابة الإبداعية.',
                                                      ),
                                                      _buildModelIndicator(
                                                        context,
                                                        'Gemma 3 12B',
                                                        Colors.amber.shade300,
                                                        ApiKeyService
                                                            .activeModel
                                                            .contains('Gemma'),
                                                        'نموذج Google السريع والمتوازن للمهام اليومية.',
                                                      ),
                                                      _buildModelIndicator(
                                                        context,
                                                        'Qwen 2.5 VL',
                                                        Colors.teal.shade300,
                                                        ApiKeyService
                                                            .activeModel
                                                            .contains('Qwen'),
                                                        'نموذج Vision-Language المتطور من Alibaba لتحليل الصور والنصوص.',
                                                      ),
                                                      _buildModelIndicator(
                                                        context,
                                                        'Kimi K2',
                                                        Colors.green.shade300,
                                                        ApiKeyService
                                                            .activeModel
                                                            .contains('Kimi'),
                                                        'نموذج ذكي جداً يتميز بالذاكرة الطويلة والتفكير العميق.',
                                                      ),
                                                      _buildModelIndicator(
                                                        context,
                                                        'Mistral 7B',
                                                        Colors.indigo.shade300,
                                                        ApiKeyService
                                                            .activeModel
                                                            .contains(
                                                              'Mistral',
                                                            ),
                                                        'نموذج Mistral الكلاسيكي القوي والموثوق للمهام العامة.',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Help Button - Absolute corner position
                                  PositionedDirectional(
                                    top: 0,
                                    end: 0,
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        onPressed: _showAIHelpDialog,
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 32,
                                              height: 32,
                                            ),
                                        splashRadius: 16,
                                        icon: Icon(
                                          Icons.help_outline,
                                          size: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Quick Stats ثابت
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Consumer<NoteProvider>(
                      builder: (context, noteProvider, _) {
                        return Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.pending_actions,
                                title: 'معلقة',
                                value: '${pendingTasks.length}',
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.check_circle,
                                title: 'اليوم',
                                value: '$completedToday',
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.note_alt,
                                title: 'ملاحظات',
                                value: '${noteProvider.allNotesCount}',
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),

                  // تم نقل المهام إلى صفحة المهام المخصصة بناءً على طلب المستخدم
                  const Spacer(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModelIndicator(
    BuildContext context,
    String modelName,
    Color color,
    bool isActive,
    String description,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: ApiKeyService.updateNotifier,
      builder: (context, _, _) {
        return FutureBuilder<int>(
          future: ApiKeyService.getRequestCount(modelName),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return InkWell(
              onTap: () =>
                  _showModelDetailsDialog(modelName, count, description, color),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.2)
                      : Colors.transparent,
                  border: Border.all(
                    color: isActive
                        ? color
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive ? color : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$modelName ($count)',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive ? null : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showModelDetailsDialog(
    String name,
    int count,
    String description,
    Color color,
  ) async {
    final lastTime = await ApiKeyService.getLastRequestTime(name);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2),
                },
                border: TableBorder.all(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  _buildTableRow('إجمالي الطلبات', '$count طلب'),
                  _buildTableRow('آخر استخدام', lastTime),
                  _buildTableRow('نوع المحتوى', 'شامل'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flash_on, size: 14, color: color),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'هذا العداد يتم تحديثه لحظياً مع كل طلب.',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('فهمت', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(value, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  void _showAIHelpDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'دليل الاستخدام الذكي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _showDetailedStepByStepGuide,
                    icon: const Icon(Icons.auto_stories, size: 18),
                    label: const Text('شرح مفصل "من الصفر"'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    _buildHelpStep(
                      '1',
                      'تعدد النماذج (Fallback)',
                      'التطبيق مصمم ليعمل بسلسلة ذكية. إذا نفد رصيد Gemini (15 طلب/دقيقة)، ينتقل المساعد تلقائياً إلى DeepSeek R1، ثم إلى Mistral لضمان عدم توقف الخدمة أبداً.',
                      Icons.account_tree,
                    ),
                    _buildHelpStep(
                      '2',
                      'احصل على مفتاح Gemini الخاص',
                      'لزيادة استقرار Gemini، يمكنك الحصول على مفتاحك الخاص مجاناً من Google AI Studio ومسحه في الإعدادات.',
                      Icons.vpn_key,
                    ),
                    _buildHelpStep(
                      '3',
                      'سر الاستخدام غير المحدود (OpenRouter)',
                      'نماذج مثل DeepSeek R1 مجانية حالياً عبر OpenRouter. سجل في OpenRouter، أحصل على مفتاح مجاني، وضعه في الإعدادات للحصول على استجابة سريعة دائماً.',
                      Icons.all_inclusive,
                    ),
                    _buildHelpStep(
                      '4',
                      'كيفية الضبط',
                      'اذهب إلى الإعدادات > إدارة مفاتيح API > وأدخل مفاتيحك هناك. التطبيق سيقوم بالباقي!',
                      Icons.settings_suggest,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ToastService.showErrorToast(context, 'لا يمكن فتح الرابط');
      }
    }
  }

  void _showDetailedStepByStepGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.child_care,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'شرح للمبتدئين (خطوة بخطوة)',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepSection(
                  'أولاً: الحصول على مفتاح Gemini (المحرك الأساسي)',
                  [
                    '1. اضغط على الزر أدناه لفتح Google AI Studio.',
                    '2. سجل الدخول بحساب جوجل الخاص بك.',
                    '3. اضغط على زر "Create API key" الأزرق في القائمة الجانبية.',
                    '4. ستظهر نافذة؛ اختر "Create API key in a new project" (الخيار الأول).',
                    '5. انتظر قليلاً ثم انسخ المفتاح الذي يظهر (يبدأ بـ "AIza...").',
                  ],
                  linkTitle: 'فتح Google AI Studio',
                  linkUrl: 'https://aistudio.google.com/app/apikey',
                ),
                const Divider(),
                _buildStepSection(
                  'ثانياً: الحصول على مفتاح OpenRouter (المحرك الشامل)',
                  [
                    '1. اضغط على الزر أدناه لفتح موقع OpenRouter.',
                    '2. سجل الدخول (يفضل استخدام حساب جوجل للسرعة).',
                    '3. اضغط على زر "Create Key" الملون.',
                    '4. سيُطلب منك اسم للمفتاح؛ اكتب أي اسم (مثلاً: "مساعدي الذكي") ثم اضغط "Create".',
                    '5. ⚠️ هام جداً: انسخ المفتاح فوراً واحفظه، لأنه لن يظهر مرة أخرى!',
                    '💡 ملاحظة: هذا المفتاح الواحد سيشغل 7 نماذج جبارة تلقائياً كبدائل عند الحاجة.',
                  ],
                  linkTitle: 'فتح OpenRouter Keys',
                  linkUrl: 'https://openrouter.ai/settings/keys',
                ),
                const Divider(),
                _buildStepSection('ثالثاً: تفعيل المفاتيح', [
                  '1. أغلق هذه النافذة وتوجه إلى "الإعدادات" في التطبيق.',
                  '2. اختر "إدارة مفاتيح API".',
                  '3. الصق كل مفتاح في خانته المخصصة واضغط "حفظ الكل".',
                  '🚀 الآن مساعدك يعمل بأقصى طاقة وبأعلى استقرار ممكن!',
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('فهمت، شكراً لك!'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSection(
    String title,
    List<String> steps, {
    String? linkTitle,
    String? linkUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...steps.map(
          (step) => Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 4),
            child: Text(
              step,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ),
        if (linkTitle != null && linkUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchUrl(linkUrl),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(linkTitle, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHelpStep(String num, String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: color),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      blur: 8,
      opacity: 0.15,
      color: Theme.of(context).colorScheme.primary,
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        width: 0.5,
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: const EdgeInsets.all(4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
