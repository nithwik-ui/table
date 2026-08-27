import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants.dart';
import 'core/storage.dart';
import 'core/api.dart';
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

  // Initialize Firebase safely (crash protection if google-services.json is missing)
  try {
    await Firebase.initializeApp();
    await _initFirebaseMessaging();
  } catch (e) {
    debugPrint('Firebase initialization failed (missing configuration files is expected for testing): $e');
  }

  runApp(const MyApp());
}

Future<void> _initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  
  // Request notifications permissions
  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // Background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Auto-register token if user has already configured their timetable
  final selection = StorageService.getSelection();
  if (selection != null) {
    final batchId = selection['batchId']!;
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await ApiService.registerDevice(token, batchId);
        debugPrint('FCM Token registered on app launch: $token');
      }
    } catch (e) {
      debugPrint('Failed to get or send FCM token: $e');
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Hive.initFlutter();
  } catch (_) {}
  debugPrint("Handling a background message: ${message.messageId}");
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
        colorScheme: ColorScheme.light(
          primary: AppConstants.primary,
          secondary: AppConstants.primaryContainer,
          tertiary: AppConstants.primaryContainer,
          surface: AppConstants.surface,
          error: AppConstants.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppConstants.textPrimary,
          outline: AppConstants.outline,
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
