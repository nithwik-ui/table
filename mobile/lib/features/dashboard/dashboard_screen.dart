import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import '../../core/updater.dart';
import '../../core/notifications.dart';
import 'home_tab.dart';
import 'week_tab.dart';
import 'changes_tab.dart';
import 'profile_tab.dart';
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
  String? _lastRemindedClassKey;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    
    // Explicitly restore/schedule exact alarms on startup for existing timetable
    final userMode = StorageService.getUserMode();
    final cachedTimetable = userMode == 'faculty' 
        ? StorageService.getFacultyTimetableCache() 
        : StorageService.getTimetableCache();
        
    if (cachedTimetable.isNotEmpty) {
      NotificationService.scheduleClassReminders(cachedTimetable);
    }
    
    _checkAndRefreshTimetable();
    if (userMode == 'student') {
      _checkForChanges();
    }
    
    // Check for updates silently on startup (after 3 seconds politeness delay)
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        _checkForUpdatesSilently();
        try {
          await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _checkAndRefreshTimetable() async {
    final userMode = StorageService.getUserMode();
    
    if (userMode == 'faculty') {
      final selection = StorageService.getFacultySelection();
      if (selection == null) return;
      
      final lastSynced = StorageService.getFacultyLastSyncedAt();
      if (lastSynced != null) {
        final diff = DateTime.now().difference(lastSynced);
        if (diff.inMinutes < 60) return;
      }

      try {
        final facultyId = selection['facultyId']!;
        final newTimetable = await ApiService.fetchFacultyTimetable(facultyId);
        await StorageService.saveFacultyTimetableCache(newTimetable);
        await StorageService.saveFacultyLastSyncedAt(DateTime.now());
        
        await NotificationService.scheduleClassReminders(newTimetable);
      } catch (_) {}
    } else {
      final selection = StorageService.getSelection();
      if (selection == null) return;
      
      final lastSynced = StorageService.getLastSyncedAt();
      if (lastSynced != null) {
        final diff = DateTime.now().difference(lastSynced);
        if (diff.inMinutes < 60) return;
      }

      try {
        final batchId = selection['batchId']!;
        final newTimetable = await ApiService.fetchTimetable(batchId);
        await StorageService.saveTimetableCache(newTimetable);
        await StorageService.saveLastSyncedAt(DateTime.now());
        _checkForChanges();
        
        await NotificationService.scheduleClassReminders(newTimetable);
      } catch (_) {}
    }
  }

  void _checkForChanges() async {
    final selection = StorageService.getSelection();
    if (selection == null) return;
    final batchId = selection['batchId']!;

    try {
      final list = await ApiService.fetchChanges(batchId);
      if (list.isNotEmpty) {
        // Compare with cached changes count to see if there is something new
        final cachedCount = StorageService.getChangesCache().length;
        if (list.length > cachedCount) {
          setState(() {
            _hasUnreadChanges = true;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Peer tab views
    final tabs = [
      const HomeTab(),
      const WeekTab(),
      const ChangesTab(),
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
                // Opened Changes tab - remove the red dot
                _hasUnreadChanges = false;
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
            BottomNavigationBarItem(
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
