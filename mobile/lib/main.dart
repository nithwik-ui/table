import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants.dart';
import 'core/storage.dart';
import 'core/api.dart';
import 'core/notifications.dart';
import 'core/sync.dart';
import 'features/onboarding/mode_selection_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Hive.initFlutter();
    await StorageService.init();
    
    if (message.data['type'] == 'calendar_override_updated') {
      final mode = message.data['target_mode'];
      final currentMode = StorageService.getUserMode() ?? 'student';
      
      if (mode == 'both' || mode == currentMode) {
        final overrides = await ApiService.fetchCalendarOverrides('', currentMode);
        if (currentMode == 'faculty') {
          await StorageService.saveFacultyCalendarOverridesCache(overrides);
        } else {
          await StorageService.saveStudentCalendarOverridesCache(overrides);
        }
        await NotificationService.reconcileReminders();
      }
    } else if (message.data['change_type'] != null) {
      // Backend fcm.ts sends change_type and batch_id
      final currentMode = StorageService.getUserMode();
      
      if (currentMode == 'student' && message.data['batch_id'] != null) {
        final selection = StorageService.getSelection();
        if (selection != null && selection['batchId'] == message.data['batch_id']) {
          // Fetch updated timetable and changes directly
          try {
            final list = await ApiService.fetchTimetable(selection['batchId']!);
            await StorageService.saveTimetableCache(list);
            
            final changesList = await ApiService.fetchChanges(selection['batchId']!);
            await StorageService.saveChangesCache(changesList);
            
            if (StorageService.isClassRemindersEnabled()) {
              await NotificationService.scheduleClassReminders(list);
            }
          } catch (_) {}
        }
      } else if (currentMode == 'faculty' && message.data['faculty_id'] != null) {
        final selection = StorageService.getFacultySelection();
        if (selection != null && selection['facultyId'] == message.data['faculty_id']) {
          try {
            final list = await ApiService.fetchFacultyTimetable(selection['facultyId']!);
            await StorageService.saveFacultyTimetableCache(list);
            
            if (StorageService.isClassRemindersEnabled()) {
              await NotificationService.scheduleClassReminders(list);
            }
          } catch (_) {}
        }
      }
    }
  } catch (e) {
    debugPrint("Background handler error: $e");
  }
}

Future<void> _initFirebaseSafely() async {
  try {
    await Firebase.initializeApp();
    
    final messaging = FirebaseMessaging.instance;
    
    // Subscribe to global topic for broadcasts
    try {
      await messaging.subscribeToTopic('sru_all_users');
      debugPrint('Subscribed to sru_all_users FCM topic');
    } catch (_) {}

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
      final userMode = StorageService.getUserMode() ?? 'student';
      final batchId = StorageService.getSelection()?['batchId'] ?? '';
      final facultyId = StorageService.getFacultySelection()?['facultyId'];

      try {
        await ApiService.registerDevice(
          fcmToken,
          batchId,
          userMode: userMode,
          facultyId: facultyId,
        );
      } catch (_) {}
    });

  } catch (e) {
    debugPrint('Firebase initialization failed (graceful fallback): $e');
  }
}

void main() {
  // Ensure Flutter engine bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Launch the UI immediately to prevent black screen delay
  runApp(const MyApp());

  // Initialize non-critical background services
  Future.microtask(() async {
    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }

    await _initFirebaseSafely();

    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdMob initialization failed (non-fatal): $e');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconcile reminders and sync when app comes to foreground
      NotificationService.reconcileReminders();
      SyncService.instance.syncTimetable();
    }
  }

  @override
  Widget build(BuildContext context) {
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
      home: const SplashController(),
    );
  }
}

class SplashController extends StatefulWidget {
  const SplashController({super.key});

  @override
  State<SplashController> createState() => _SplashControllerState();
}

class _SplashControllerState extends State<SplashController> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await StorageService.init();
      // Safely schedule reminders based on stored state on app startup
      await NotificationService.reconcileReminders();
      
      // Trigger background sync on startup
      SyncService.instance.syncTimetable();
    } catch (e) {
      debugPrint('Local storage initialization failed: $e');
    }

    if (mounted) {
      final userMode = StorageService.getUserMode();
      final hasStudent = StorageService.hasSelection();
      final hasFaculty = StorageService.hasFacultySelection();
      
      Widget nextScreen;
      if (userMode == 'student' && hasStudent) {
        nextScreen = const DashboardScreen();
      } else if (userMode == 'faculty' && hasFaculty) {
        nextScreen = const DashboardScreen();
      } else {
        nextScreen = const ModeSelectionScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 64,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppConstants.primary),
          ],
        ),
      ),
    );
  }
}
