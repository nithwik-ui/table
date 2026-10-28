import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants.dart';
import 'core/ad_service.dart';
import 'core/storage.dart';
import 'core/api.dart';
import 'core/notifications.dart';
import 'core/sync.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/auth_state.dart';
import 'core/auth/secure_session_store.dart';
import 'core/migration.dart';
import 'core/sraap/sraap_session_manager.dart';
import 'core/sraap/sraap_academic_service.dart';
import 'core/timetable/timetable_repository.dart';
import 'features/onboarding/mode_selection_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Hive.initFlutter();
    await StorageService.init();
    await NotificationService.init();
    
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
      // Backend fcm.ts sends change_type
      final currentMode = StorageService.getUserMode();
      final profile = StorageService.getProfile();
      
      if (currentMode == 'student' && message.data['batch_id'] != null) {
        if (profile != null && profile['id'] == message.data['batch_id']) {
          try {
            await SyncService.instance.syncTimetable();
          } catch (_) {}
        }
      } else if (currentMode == 'faculty' && message.data['faculty_id'] != null) {
        if (profile != null && profile['id'] == message.data['faculty_id']) {
          try {
            await SyncService.instance.syncTimetable();
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
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyD9_WzJsEJSi-0ke0rdZVdA6ohgX_yib-Q",
          appId: "1:712842876134:web:6a81c13779ec2828949727",
          messagingSenderId: "712842876134",
          projectId: "timetable-77a7d",
          authDomain: "timetable-77a7d.firebaseapp.com",
          storageBucket: "timetable-77a7d.firebasestorage.app",
          measurementId: "G-WRP2DM4ZRL",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    
    final messaging = FirebaseMessaging.instance;
    
    // Request permission (handles Android 13+ POST_NOTIFICATIONS)
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
    
    // Subscribe to global topic for broadcasts (mobile only)
    if (!kIsWeb) {
      try {
        // Unsubscribe from v2.0 topics to prevent contamination
        await messaging.unsubscribeFromTopic('all_users');
        await messaging.unsubscribeFromTopic('all');
        await messaging.unsubscribeFromTopic('students');
        
        await messaging.subscribeToTopic('sru_all_users');
        debugPrint('Subscribed to sru_all_users FCM topic');
      } catch (_) {}

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } else {
      // Web FCM setup
      try {
        final webToken = await messaging.getToken(
          vapidKey: "BLfXNackp6Rs_phEfbaIPWdKm7HADbl3RYGEhjU2qocshKk7CbeIX0Gb5zLQ9EH84nkSaZSiJCcENw4wWf7e12M",
        );
        if (webToken != null && webToken.isNotEmpty) {
          debugPrint('Web FCM token obtained: $webToken');
          final userMode = StorageService.getUserMode() ?? 'student';
          final profile = StorageService.getProfile();
          final id = profile?['id']?.toString() ?? 
              profile?['roll_no']?.toString() ?? 
              StorageService.getStudentRollNumber() ?? 
              StorageService.getUserIdentifier() ?? '';
          final batchId = profile?['batch_id']?.toString() ?? '63a84ab2-8ee2-4ea7-b473-38858889428a';
          await ApiService.registerDevice(
            webToken,
            userMode == 'student' ? batchId : '',
            userMode: userMode,
            facultyId: userMode == 'faculty' ? id : id,
          );
        }
      } catch (e) {
        debugPrint('Web FCM registration error: $e');
      }
    }

    // Foreground message handler using local notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        NotificationService.showForegroundNotification(
          message.notification!.title,
          message.notification!.body,
          message.data,
        );
      }
    });

    // Handle background notification clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final currentRole = StorageService.getUserMode();
      final session = currentRole != null && currentRole.isNotEmpty
          ? await SecureSessionStore.getSession(role: currentRole)
          : await SecureSessionStore.getSession();
      final hasValidSession = session != null &&
          session['cookie'] != null &&
          (session['cookie'] as String).trim().isNotEmpty;

      if (hasValidSession) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 0)),
          (route) => false,
        );
      }
    });

    // Auto-refresh token if server rotates it
    messaging.onTokenRefresh.listen((fcmToken) async {
      final userMode = StorageService.getUserMode() ?? 'student';
      final profile = StorageService.getProfile();
      final id = profile?['id']?.toString() ?? 
          profile?['roll_no']?.toString() ?? 
          StorageService.getStudentRollNumber() ?? 
          StorageService.getUserIdentifier() ?? '';

      final batchId = profile?['batch_id']?.toString() ?? '63a84ab2-8ee2-4ea7-b473-38858889428a';

      try {
        await ApiService.registerDevice(
          fcmToken,
          userMode == 'student' ? batchId : '',
          userMode: userMode,
          facultyId: userMode == 'faculty' ? id : id,
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

  // Prevent any unhandled widget build exception from rendering an ugly grey box
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('[ERROR_CATCHER] Widget build error intercepted: ${details.exception}');
    return const SizedBox.shrink();
  };

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

    if (!kIsWeb) {
      try {
        await AdService.instance.init();
      } catch (e) {
        debugPrint('AdMob initialization failed (non-fatal): $e');
      }
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
      navigatorKey: navigatorKey,
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
    bool isFreshUpdate = false;
    try {
      await StorageService.init();
      await AppDataMigrationManager.runMigrationIfNeeded();

      const int currentBuild = 31;
      final int lastOpenedBuild = StorageService.getInt('last_opened_build_number') ?? 0;
      final bool v31ResetDone = (StorageService.getInt('v31_fresh_start_done') ?? 0) == 1;

      if (lastOpenedBuild < currentBuild || !v31ResetDone) {
        debugPrint('[APP_INIT] Version update to build $currentBuild detected. Performing fresh start.');
        isFreshUpdate = true;
        await AuthRepository.instance.logout();
        await SecureSessionStore.clearSession();
        await SraapSessionManager.instance.clearSession();
        await StorageService.clearAll();
        await StorageService.setInt('last_opened_build_number', currentBuild);
        await StorageService.setInt('v31_fresh_start_done', 1);
      }

      TimetableRepository.instance.init();
      if (!isFreshUpdate) {
        await SraapSessionManager.instance.restoreSession();
        SraapAcademicService.instance.startKeepAlive();
        await NotificationService.reconcileReminders();
        await AuthRepository.instance.restoreSession();
      }
    } catch (e) {
      debugPrint('Local storage initialization failed: $e');
    }

    if (mounted) {
      final authState = AuthRepository.instance.state;
      
      bool launchedFromNotification = false;
      try {
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          launchedFromNotification = true;
        }
      } catch (_) {}
      
      Widget nextScreen;
      
      if (isFreshUpdate) {
        nextScreen = const ModeSelectionScreen();
      } else {
        final currentRole = StorageService.getUserMode();
        final session = currentRole != null && currentRole.isNotEmpty
            ? await SecureSessionStore.getSession(role: currentRole)
            : await SecureSessionStore.getSession();

        final hasValidSession = session != null &&
            session['cookie'] != null &&
            (session['cookie'] as String).trim().isNotEmpty &&
            (authState == AuthState.ready || authState == AuthState.authenticated);

        if (hasValidSession) {
          nextScreen = DashboardScreen(initialTab: launchedFromNotification ? 0 : 0);
        } else {
          nextScreen = const ModeSelectionScreen();
        }
      }

      if (!mounted) return;
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
