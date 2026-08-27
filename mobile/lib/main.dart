import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'core/storage.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  // Ensure Flutter engine bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Caching safely to prevent crash-on-launch
  try {
    await StorageService.init();
  } catch (e) {
    debugPrint('Local storage initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Decide initial route based on cached batch selection
    final bool hasExistingSelection = StorageService.hasSelection();

    return MaterialApp(
      title: 'SRU Timetable',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppConstants.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primary,
          primary: AppConstants.primary,
          surface: AppConstants.surface,
          error: AppConstants.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppConstants.textPrimary),
        ),
      ),
      home: hasExistingSelection ? const DashboardScreen() : const WelcomeScreen(),
    );
  }
}
