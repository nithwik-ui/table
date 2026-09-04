import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:io';
import '../../core/constants.dart';
import '../../core/api.dart';
import '../../core/storage.dart';
import '../../core/notifications.dart';
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
          await NotificationService.scheduleClassReminders(entries);
        }
      } catch (e) {
        debugPrint('[SYNC] Reminder scheduling failed: $e');
      }

      // Try to register device token with fallback (never blocks)
      String fcmToken = 'local_device';
      try {
        final token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
        if (token != null) {
          fcmToken = token;
        }
      } catch (_) {}
      await ApiService.registerDevice(fcmToken, widget.batchId);
      
      // Delay briefly for animation effect
      await Future.delayed(const Duration(seconds: 2));

      // 4. Save batch variables to local storage (marks onboarding as complete)
      await StorageService.saveSelection(
        degree: widget.degree,
        year: widget.year,
        batchId: widget.batchId,
        batchCode: widget.batchCode,
      );
      
      // Explicitly set user mode since first-time users skip mode_selection_screen logic
      await StorageService.setUserMode('student');

      // 5. Update data freshness timestamp
      await StorageService.saveLastSyncedAt(DateTime.now());

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
      if (e is SocketException || e is TimeoutException) {
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
                    const CircularProgressIndicator(color: AppConstants.primary),
                    const SizedBox(height: 24),
                    Text(
                      _statusText,
                      style: AppConstants.getBodyLarge().copyWith(fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const Icon(
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
