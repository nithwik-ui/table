import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/sync.dart';
import '../../core/updater.dart';
import '../../core/notifications.dart';
import '../../core/api.dart';
import 'home_tab.dart';
import 'week_tab.dart';
import 'changes_tab.dart';
import 'profile_tab.dart';
import '../academic/academic_tab.dart';
import 'ad_banner.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTab;

  const DashboardScreen({super.key, this.initialTab = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentIndex;
  bool _hasUnreadChanges = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    
    // Explicitly restore/schedule exact alarms on startup for existing timetable
    final userMode = StorageService.getUserMode() ?? 'student';
    final cachedTimetable = userMode == 'faculty' 
        ? StorageService.getFacultyTimetableCache() 
        : StorageService.getTimetableCache();
        
    if (cachedTimetable.isNotEmpty) {
      NotificationService.reconcileReminders();
    } else {
      // If timetable cache is empty, trigger an immediate sync
      SyncService.instance.syncTimetable();
    }
    
    // Check for updates silently on startup (after 3 seconds politeness delay)
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        _checkForUpdatesSilently();
        try {
          final settings = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
          if (settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional) {
            final token = await FirebaseMessaging.instance.getToken();
            if (token != null && token.isNotEmpty) {
              final userMode = StorageService.getUserMode() ?? 'student';
              final profile = StorageService.getProfile();
              final id = profile?['id']?.toString() ?? 
                  profile?['roll_no']?.toString() ?? 
                  StorageService.getStudentRollNumber() ?? 
                  StorageService.getUserIdentifier() ?? '';
              await ApiService.registerDevice(
                token,
                userMode == 'student' ? id : '',
                userMode: userMode,
                facultyId: userMode == 'faculty' ? id : null,
              );
              debugPrint('FCM device successfully registered with backend');
            }
          }
        } catch (e) {
          debugPrint('FCM startup registration error: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = StorageService.isStudentMode();

    // Peer tab views
    final tabs = [
      const HomeTab(),
      const WeekTab(),
      isStudent ? const AcademicTab() : const ChangesTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
            ),
          ),
          if (_currentIndex != 3) const AdBanner(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppConstants.outline, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (index == 2) {
                // Opened Changes/Academic tab - remove the red dot for faculty
                if (!isStudent) {
                  _hasUnreadChanges = false;
                }
              }
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppConstants.surface,
          selectedItemColor: AppConstants.primary,
          unselectedItemColor: AppConstants.textSecondary,
          selectedLabelStyle: AppConstants.getLabelSmall(color: AppConstants.primary).copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_view_week_outlined),
              activeIcon: Icon(Icons.calendar_view_week),
              label: 'Week',
            ),
            isStudent
                ? const BottomNavigationBarItem(
                    icon: Icon(Icons.school_outlined),
                    activeIcon: Icon(Icons.school),
                    label: 'Academic',
                  )
                : BottomNavigationBarItem(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.history_outlined),
                        if (_hasUnreadChanges)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppConstants.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    activeIcon: const Icon(Icons.history),
                    label: 'Changes',
                  ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _checkForUpdatesSilently() async {
    final result = await UpdateService.checkForUpdates();
    if (result['status'] == 'update_available') {
      if (mounted) {
        _showUpdateDialog(result['latestTag'], result['downloadUrl']);
      }
    }
  }

  void _showUpdateDialog(String latestTag, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Text('A new version of SRU Timetable ($latestTag) is available on GitHub. Would you like to download it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open download link.')),
                    );
                  }
                }
              },
              child: const Text('Download', style: TextStyle(color: AppConstants.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
