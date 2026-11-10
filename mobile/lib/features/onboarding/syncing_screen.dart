import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import '../../core/constants.dart';
import '../../core/api.dart';
import '../../core/storage.dart';
import '../../core/notifications.dart';
import '../../core/timetable/timetable_repository.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/secure_session_store.dart';
import '../dashboard/dashboard_screen.dart';

class SyncingScreen extends StatefulWidget {
  final String degree;
  final String year;
  final String batchId;
  final String batchCode;

  const SyncingScreen({
    super.key,
    required this.degree,
    required this.year,
    required this.batchId,
    required this.batchCode,
  });

  @override
  State<SyncingScreen> createState() => _SyncingScreenState();
}

class _SyncingScreenState extends State<SyncingScreen> {
  bool _isSyncing = true;
  String _statusText = 'Setting up your timetable...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  void _startSync() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
      _statusText = 'Setting up your timetable...';
    });

    try {
      // 1. Fetch live batch timetable entries and calendar overrides
      final entries = await ApiService.fetchTimetable(widget.batchId);
      final overrides = await ApiService.fetchCalendarOverrides('', 'student');
      
      // 2. Cache timetable entries locally
      await StorageService.saveTimetableCache(entries);
      await StorageService.saveStudentCalendarOverridesCache(overrides);

      // 2.5 Schedule local reminders if enabled (default true)
      try {
        if (StorageService.isClassRemindersEnabled()) {
          await NotificationService.reconcileReminders();
        }
      } catch (e) {
        debugPrint('[SYNC] Reminder scheduling failed: $e');
      }

      // Try to register device token with fallback (never blocks)
      String fcmToken = 'local_device';
      try {
        final token = kIsWeb
            ? await FirebaseMessaging.instance.getToken(vapidKey: AppConstants.fcmVapidKey).timeout(const Duration(seconds: 5))
            : await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 5));
        if (token != null) {
          fcmToken = token;
        }
      } catch (_) {}
      await ApiService.registerDevice(fcmToken, widget.batchId);
      
      // Delay briefly for animation effect
      await Future.delayed(const Duration(milliseconds: 300));

      final savedName = StorageService.getUserName();

      // 4. Save batch variables to local storage (marks onboarding as complete)
      await StorageService.saveProfile({
        'batch': widget.batchCode,
        'batch_name': widget.batchCode,
        'department': widget.degree,
        'degree': widget.degree,
        'year': widget.year,
        'batch_id': widget.batchId,
        if (savedName != null && savedName.isNotEmpty) 'name': savedName,
        'role': 'student',
      });
      await StorageService.saveUserIdentifier(widget.batchCode);

      // Explicitly set user mode and safe batch session
      await StorageService.setUserMode('student');
      await SecureSessionStore.saveSession({
        'cookie': 'batch_mode=${widget.batchCode}',
        'role': 'student',
        'identifier': widget.batchCode,
        'batch_id': widget.batchId,
        'batch_code': widget.batchCode,
      }, role: 'student');
      await AuthRepository.instance.restoreSession();

      // 5. Update data freshness timestamp and shared repository
      final syncedAt = DateTime.now();
      await StorageService.saveLastSyncedAt(syncedAt);
      TimetableRepository.instance.updateTimetable(
        entries,
        source: 'cloudflare_batch',
        syncedAt: syncedAt,
      );

      if (mounted) {
        // Navigate to dashboard and wipe the navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[SYNC] Exception: $e');
      debugPrint('[SYNC] StackTrace: $stackTrace');
      
      String displayError = 'Unknown error occurred.';
      final eStr = e.toString().toLowerCase();
      if (eStr.contains('socketexception') || eStr.contains('clientexception') || eStr.contains('xmlhttprequest') || eStr.contains('timeoutexception')) {
        displayError = 'Network failure. Please check your internet connection.';
      } else {
        displayError = e.toString().replaceFirst('Exception: ', '');
      }
      
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _errorMessage = displayError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingContainer * 1.5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: AppConstants.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                boxShadow: AppConstants.shadowLevel2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Text(
                    'sru',
                    style: AppConstants.getDisplay(color: AppConstants.primary).copyWith(fontSize: 48),
                  ),
                  const SizedBox(height: 32),
                  if (_isSyncing) ...[
                    CircularProgressIndicator(color: AppConstants.primary),
                    const SizedBox(height: 24),
                    Text(
                      _statusText,
                      style: AppConstants.getBodyLarge().copyWith(fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Icon(
                      Icons.cloud_off_outlined,
                      color: AppConstants.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sync Failed',
                      style: AppConstants.getHeadline().copyWith(color: AppConstants.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Unknown error occurred.',
                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _startSync,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primary,
                        foregroundColor: AppConstants.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: AppConstants.getBodyLarge(color: AppConstants.onPrimary).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
