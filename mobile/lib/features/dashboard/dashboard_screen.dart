import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import 'home_tab.dart';
import 'week_tab.dart';
import 'changes_tab.dart';
import 'profile_tab.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTab;

  const DashboardScreen({super.key, this.initialTab = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentIndex;
  bool _hasUnreadChanges = false;
  Timer? _reminderTimer;
  String? _lastRemindedClassKey;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _checkAndRefreshTimetable();
    _checkForChanges();
    _startReminderTimer();
    
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
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _checkAndRefreshTimetable() async {
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
    } catch (_) {}
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
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
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

  void _startReminderTimer() {
    // Check every 30 seconds for upcoming classes
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkUpcomingClassReminder();
      }
    });
  }

  void _checkUpcomingClassReminder() {
    if (!StorageService.isClassRemindersEnabled()) return;

    final timetable = StorageService.getTimetableCache();
    if (timetable.isEmpty) return;

    // Current IST Time
    final nowIST = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = weekdays[nowIST.weekday];
    final currentMinutes = nowIST.hour * 60 + nowIST.minute;

    for (final c in timetable) {
      if (c['day'] != currentDay) continue;

      final startParts = (c['start_time'] as String).split(':').map(int.parse).toList();
      final startMinutes = startParts[0] * 60 + startParts[1];

      final diff = startMinutes - currentMinutes;
      if (diff == 15) {
        final classKey = "${c['day']}_${c['start_time']}_${c['subject']}";
        if (_lastRemindedClassKey == classKey) return; // Already reminded

        _lastRemindedClassKey = classKey;
        _showReminderNotification(c);
        break; // Show one at a time
      }
    }
  }

  void _showReminderNotification(Map<String, dynamic> c) {
    final room = (c['room'] as String? ?? 'No Room').split('_')[0];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppConstants.primary,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusButton)),
        content: Row(
          children: [
            const Icon(Icons.alarm, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class starting in 15 mins',
                    style: AppConstants.getHeadline(color: Colors.white).copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c['subject']} in $room',
                    style: AppConstants.getBodyMedium(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void _checkForUpdatesSilently() async {
    final release = await ApiService.fetchLatestGithubRelease();

    final String latestTag = release['tag_name'] as String? ?? '1.0.1';
    final String htmlUrl = release['html_url'] as String? ?? 'https://github.com/${AppConstants.githubRepo}';
    
    String? downloadUrl;
    final assets = release['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }
    
    final targetUrl = downloadUrl ?? htmlUrl;

    if (_isNewerVersion(AppConstants.currentVersion, latestTag)) {
      if (mounted) {
        _showUpdateDialog(latestTag, targetUrl);
      }
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final cleanCurrent = current.replaceAll('v', '').replaceAll('+', '.');
      final cleanLatest = latest.replaceAll('v', '').replaceAll('+', '.');
      
      final currentParts = cleanCurrent.split('.').map(int.parse).toList();
      final latestParts = cleanLatest.split('.').map(int.parse).toList();
      
      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) {
          return true;
        }
        if (latestParts[i] > currentParts[i]) {
          return true;
        } else if (latestParts[i] < currentParts[i]) {
          return false;
        }
      }
    } catch (_) {}
    return false;
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
