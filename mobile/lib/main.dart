import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants.dart';
import 'core/storage.dart';
import 'core/api.dart';
import 'core/notifications.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Hive.initFlutter();
  } catch (_) {}
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> _initFirebaseSafely() async {
  try {
    await Firebase.initializeApp();
    
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground message handler using local notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        NotificationService.showForegroundNotification(
          message.notification!.title,
          message.notification!.body,
        );
      }
    });

    // Auto-refresh token if server rotates it
    messaging.onTokenRefresh.listen((fcmToken) async {
      final selection = StorageService.getSelection();
      if (selection != null) {
        final batchId = selection['batchId']!;
        try {
          await ApiService.registerDevice(fcmToken, batchId);
        } catch (_) {}
      }
    });

  } catch (e) {
    debugPrint('Firebase initialization failed (graceful fallback): $e');
  }
}

void main() async {
  // Ensure Flutter engine bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Caching safely to prevent crash-on-launch
  try {
    await StorageService.init();
  } catch (e) {
    debugPrint('Local storage initialization failed: $e');
  }

  // Initialize Notifications
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Notification service initialization failed: $e');
  }

  // Initialize Firebase (safely wrapped in try/catch to NEVER block startup)
  await _initFirebaseSafely();

  // Initialize AdMob safely — runs after runApp() so it never blocks startup
  // If AdMob fails, the app still works perfectly, banners just won't show
  Future.microtask(() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdMob initialization failed (non-fatal): $e');
    }
  });

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
