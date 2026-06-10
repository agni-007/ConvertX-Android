import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/convert_screen.dart';
import 'screens/history_screen.dart';
import 'screens/presets_screen.dart';
import 'screens/settings_screen.dart';
import 'services/history_service.dart';
import 'services/preset_service.dart';
import 'core/app_bus.dart';
import 'core/temp_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await HistoryService.instance.init();
  await PresetService.instance.init();
  await TempManager.instance.purgeAll();
  runApp(const ConvertXApp());
}

class ConvertXApp extends StatelessWidget {
  const ConvertXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConvertX',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8F8FC),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        indicatorColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final _screens = const [
    ConvertScreen(),
    HistoryScreen(),
    PresetsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppBus.navIndex.addListener(_onNavChanged);
  }

  @override
  void dispose() {
    AppBus.navIndex.removeListener(_onNavChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onNavChanged() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Purge temp files when the app is going away (FR-AND-012)
    if (state == AppLifecycleState.detached) {
      TempManager.instance.purgeAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: AppBus.navIndex.value, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: AppBus.navIndex.value,
        onDestinationSelected: (i) => AppBus.navIndex.value = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.swap_horiz_outlined), selectedIcon: Icon(Icons.swap_horiz), label: 'Convert'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Presets'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
