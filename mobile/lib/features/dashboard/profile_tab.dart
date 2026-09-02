import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import '../../core/updater.dart';
import '../../core/notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../onboarding/degree_screen.dart';
import '../onboarding/faculty_selection_screen.dart';
import '../onboarding/mode_selection_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String _initials = 'S';
  String _displayName = 'Student';
  String _degreeYearText = '';
  String _batchCode = '';
  String _lastSyncedText = 'Never';
  
  bool _notificationsEnabled = true;
  bool _remindersEnabled = true;
  bool _isRefreshing = false;
  String _currentVersion = AppConstants.currentVersion;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _currentVersion = info.version);
    }).catchError((_) {});

    final userMode = StorageService.getUserMode();

    if (userMode == 'faculty') {
      final selection = StorageService.getFacultySelection();
      
      String initials = 'F';
      String dispName = 'Faculty';
      if (selection != null && selection['facultyName'] != null) {
        dispName = selection['facultyName']!.trim();
        initials = dispName.substring(0, 1).toUpperCase();
      }

      final lastSynced = StorageService.getFacultyLastSyncedAt();
      String lastText = 'Never';
      if (lastSynced != null) {
        lastText = DateFormat('MMM d, h:mm a').format(lastSynced);
      }

      setState(() {
        _displayName = dispName;
        _initials = initials;
        _lastSyncedText = lastText;
        _notificationsEnabled = StorageService.isNotificationsEnabled();
        _remindersEnabled = StorageService.isClassRemindersEnabled();

        if (selection != null) {
          _degreeYearText = 'Faculty Mode';
          _batchCode = selection['facultyId'] ?? '';
        }
      });
    } else {
      final name = StorageService.getUserName();
      final selection = StorageService.getSelection();
      
      // Initials calculation
      String initials = 'S';
      String dispName = 'Student';
      if (name != null && name.trim().isNotEmpty) {
        dispName = name.trim();
        initials = dispName.substring(0, 1).toUpperCase();
      }

      // Last synced calculation
      final lastSynced = StorageService.getLastSyncedAt();
      String lastText = 'Never';
      if (lastSynced != null) {
        lastText = DateFormat('MMM d, h:mm a').format(lastSynced);
      }

      setState(() {
        _displayName = dispName;
        _initials = initials;
        _lastSyncedText = lastText;
        _notificationsEnabled = StorageService.isNotificationsEnabled();
        _remindersEnabled = StorageService.isClassRemindersEnabled();

        if (selection != null) {
          _degreeYearText = '${selection['degree']} · ${selection['year']} Year';
          _batchCode = selection['batchCode']!;
        }
      });
    }
  }

  void _onChangeTimetable() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Timetable?'),
          content: const Text('This will remove your currently saved timetable and let you select a new one.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                
                await NotificationService.cancelAll();
                
                if (StorageService.getUserMode() == 'faculty') {
                  await StorageService.clearFacultySelection();
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => FacultySelectionScreen()),
                    (route) => false,
                  );
                } else {
                  await StorageService.clearSelection();
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const DegreeScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Change', style: TextStyle(color: AppConstants.primary)),
            ),
          ],
        );
      },
    );
  }

  void _onSwitchMode() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isFaculty = StorageService.getUserMode() == 'faculty';
        final targetMode = isFaculty ? 'Student' : 'Faculty';
        return AlertDialog(
          title: Text('Switch to $targetMode?'),
          content: Text('This will switch your timetable mode to $targetMode. Your existing configurations will be saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                
                await NotificationService.cancelAll();
                
                // Directly switch via ModeSelectionScreen logic
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => const ModeSelectionScreen(isSwitching: true),
                  ),
                );
              },
              child: const Text('Switch', style: TextStyle(color: AppConstants.primary)),
            ),
          ],
        );
      },
    );
  }

  void _toggleNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    await StorageService.setNotificationsEnabled(val);
    
    // Attempt to update preferences on server if selection exists
    final selection = StorageService.getSelection();
    if (selection != null) {
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await ApiService.updatePreferences(fcmToken, val);
        }
      } catch (e) {
        debugPrint('Failed to update FCM preferences: $e');
      }
    }
  }

  void _toggleReminders(bool val) async {
    setState(() => _remindersEnabled = val);
    await StorageService.setClassRemindersEnabled(val);
    if (val) {
      final list = StorageService.getTimetableCache();
      if (list.isNotEmpty) {
        await NotificationService.scheduleClassReminders(list);
      }
    } else {
      await NotificationService.cancelAll();
    }
  }

  Future<void> _refreshTimetable() async {
    final selection = StorageService.getSelection();
    if (selection == null) return;
    final batchId = selection['batchId']!;

    setState(() => _isRefreshing = true);

    try {
      final userMode = StorageService.getUserMode();
      List<dynamic> list = [];
      if (userMode == 'faculty') {
        final facultyId = StorageService.getFacultySelection()?['facultyId'];
        if (facultyId != null) {
          list = await ApiService.fetchFacultyTimetable(facultyId);
          await StorageService.saveFacultyTimetableCache(list);
          await StorageService.saveFacultyLastSyncedAt(DateTime.now());
        }
      } else {
        list = await ApiService.fetchTimetable(batchId);
        await StorageService.saveTimetableCache(list);
        await StorageService.saveLastSyncedAt(DateTime.now());
      }
      
      final remindersEnabled = StorageService.isClassRemindersEnabled();
      if (remindersEnabled && list.isNotEmpty) {
        await NotificationService.scheduleClassReminders(list);
      }
      
      setState(() => _isRefreshing = false);
      _loadProfileData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable successfully updated!')),
        );
      }
    } catch (e) {
      setState(() => _isRefreshing = false);
      if (mounted) {
        String msg = 'Could not refresh. You are offline.';
        if (e is! SocketException && e is! TimeoutException) {
           msg = e.toString().replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  Future<void> _clearCacheOnly() async {
    // Clear only cache (keeping selection/name intact)
    await StorageService.saveTimetableCache([]);
    _loadProfileData();
    
    // Resync immediately
    await _refreshTimetable();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simple Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                children: [
                  const SizedBox(height: 12),
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppConstants.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                      boxShadow: AppConstants.shadowLevel1,
                      border: Border.all(color: AppConstants.outline),
                    ),
                    child: Column(
                      children: [
                        // Initials Avatar
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppConstants.secondaryContainer,
                          child: Text(
                            _initials,
                            style: AppConstants.getDisplay(color: AppConstants.primary).copyWith(fontSize: 28),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _displayName,
                          style: AppConstants.getHeadline().copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _degreeYearText,
                          style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _batchCode,
                          style: AppConstants.getMonoLabel(color: AppConstants.primary),
                        ),
                        const SizedBox(height: 16),
                        // Ghost Link: Change Timetable
                        TextButton(
                          onPressed: _onChangeTimetable,
                          style: TextButton.styleFrom(foregroundColor: AppConstants.primary),
                          child: Text(
                            'Change timetable',
                            style: AppConstants.getBodyLarge(color: AppConstants.primary).copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preferences Section
                  Text(
                    'PREFERENCES',
                    style: AppConstants.getLabelSmall().copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppConstants.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                      boxShadow: AppConstants.shadowLevel1,
                      border: Border.all(color: AppConstants.outline),
                    ),
                    child: Column(
                      children: [
                        // Notifications row
                        SwitchListTile(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          title: Text('Push Notifications', style: AppConstants.getBodyLarge()),
                          subtitle: Text('Get notified of timetable updates.', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                          activeThumbColor: AppConstants.primary,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16, color: AppConstants.outline),
                        // Class reminders row
                        SwitchListTile(
                          value: _remindersEnabled,
                          onChanged: _toggleReminders,
                          title: Text('Class Reminders', style: AppConstants.getBodyLarge()),
                          subtitle: Text('Remind me before each session.', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                          activeThumbColor: AppConstants.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Data Sync Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DATA MANAGEMENT',
                        style: AppConstants.getLabelSmall().copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Last synced: $_lastSyncedText',
                        style: AppConstants.getLabelSmall(color: AppConstants.textSecondary).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppConstants.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                      boxShadow: AppConstants.shadowLevel1,
                      border: Border.all(color: AppConstants.outline),
                    ),
                    child: Column(
                      children: [
                        // Refresh timetable
                        ListTile(
                          leading: const Icon(Icons.sync, color: AppConstants.primary),
                          title: Text('Refresh timetable', style: AppConstants.getBodyLarge()),
                          trailing: _isRefreshing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary))
                              : const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                          onTap: _isRefreshing ? null : _refreshTimetable,
                        ),
                        const Divider(height: 1, color: AppConstants.outline),
                        // Check for updates
                        ListTile(
                          leading: const Icon(Icons.update, color: AppConstants.primary),
                          title: Text('Check for updates', style: AppConstants.getBodyLarge()),
                          trailing: _isCheckingUpdates
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary))
                              : const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                          onTap: _isRefreshing || _isCheckingUpdates ? null : () => _checkForUpdates(context),
                        ),
                        const Divider(height: 1, color: AppConstants.outline),
                        // Clear cache
                        ListTile(
                          leading: const Icon(Icons.delete_outline, color: AppConstants.warning),
                          title: Text('Clear cache', style: AppConstants.getBodyLarge(color: AppConstants.warning)),
                          trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                          onTap: _isRefreshing ? null : _clearCacheOnly,
                        ),
                        const Divider(height: 1, color: AppConstants.outline),
                        // Switch mode
                        ListTile(
                          leading: Icon(
                            StorageService.getUserMode() == 'faculty' ? Icons.school_outlined : Icons.person_outline,
                            color: AppConstants.purpleAccent,
                          ),
                          title: Text(
                            StorageService.getUserMode() == 'faculty' ? 'Switch to student' : 'Switch to faculty',
                            style: AppConstants.getBodyLarge(color: AppConstants.purpleAccent),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                          onTap: _isRefreshing ? null : _onSwitchMode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // About / App version
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'SRU Timetable v$_currentVersion',
                          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Open-source dashboard updates',
                          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCheckingUpdates = false;

  Future<void> _checkForUpdates(BuildContext context, {bool showToast = true}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCheckingUpdates = true);
    
    final release = await UpdateService.checkForUpdates();
    setState(() => _isCheckingUpdates = false);

    if (release['status'] == 'timeout') {
      if (showToast && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Update check timed out.')),
        );
      }
      return;
    }
    if (release['status'] == 'no_internet') {
      if (showToast && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('You\'re offline.')),
        );
      }
      return;
    }
    if (release['status'] == 'no_release' || release['status'] == 'up_to_date') {
      if (showToast && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('App is up to date!')),
        );
      }
      return;
    }
    if (release['status'] == 'error') {
      if (showToast && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(release['message'] ?? 'Unable to check for updates right now.')),
        );
      }
      return;
    }

    if (release['status'] == 'update_available') {
      if (mounted) {
        _showUpdateDialog(release['latestTag'], release['downloadUrl']);
      }
    }
  }



  void _showUpdateDialog(String latestTag, String downloadUrl) {
    final messenger = ScaffoldMessenger.of(context);
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
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Could not open download link.')),
                  );
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

