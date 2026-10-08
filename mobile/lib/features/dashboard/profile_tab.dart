import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import '../../core/notifications.dart';
import '../../core/sync.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../onboarding/mode_selection_screen.dart';
import 'sync_center_screen.dart';
import '../../core/sraap/sraap_academic_service.dart';
import '../../core/auth/auth_repository.dart';

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
  String _rollNumber = '';
  String _registeredContact = '';
  String _lastSyncedText = 'Never';
  
  bool _notificationsEnabled = true;
  bool _remindersEnabled = true;
  bool _isRefreshing = false;
  String _currentVersion = AppConstants.currentVersion;

  bool _timetableChangesEnabled = true;
  bool _roomChangesEnabled = true;
  bool _facultyChangesEnabled = true;
  bool _cancelledClassesEnabled = true;
  bool _generalAnnouncementsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    SyncService.instance.addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted) {
      if (!SyncService.instance.isSyncing) {
        setState(() {
          _isRefreshing = false;
        });
        _loadProfileData();
      } else {
        setState(() {
          _isRefreshing = true;
        });
      }
    }
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncUpdate);
    super.dispose();
  }

  void _loadProfileData() {
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _currentVersion = info.version);
    }).catchError((_) {});

    final userMode = StorageService.getUserMode();

    if (userMode == 'faculty') {
      final profile = StorageService.getProfile();
      String initials = 'F';
      String dispName = 'Faculty';
      if (profile != null && profile['name'] != null) {
        dispName = profile['name']!.trim();
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
        
        _timetableChangesEnabled = StorageService.isTimetableChangesEnabled();
        _roomChangesEnabled = StorageService.isRoomChangesEnabled();
        _facultyChangesEnabled = StorageService.isFacultyChangesEnabled();
        _cancelledClassesEnabled = StorageService.isCancelledClassesEnabled();
        _generalAnnouncementsEnabled = StorageService.isGeneralAnnouncementsEnabled();

        if (profile != null) {
          _degreeYearText = profile['department'] ?? 'Faculty Mode';
          _batchCode = profile['id'] ?? '';
        } else {
          _degreeYearText = 'Faculty Mode';
          _batchCode = '';
        }
      });
    } else {
      final profile = StorageService.getProfile();
      
      String dispName = profile?['name']?.toString().trim() ?? StorageService.getUserName() ?? 'Student';
      if (dispName.isEmpty) dispName = 'Student';
      String initials = dispName.isNotEmpty ? dispName.substring(0, 1).toUpperCase() : 'S';

      String roll = profile?['roll_number'] ?? profile?['id'] ?? StorageService.getStudentRollNumber() ?? '';
      if (roll == 'Unknown' || roll.isEmpty) {
        final id = StorageService.getUserIdentifier() ?? '';
        if (RegExp(r'\b2[0-9][0-9A-Za-z]{2}[A-Za-z0-9]{6}\b').hasMatch(id)) {
          roll = id;
        }
      }

      String batch = profile?['batch'] ?? profile?['department'] ?? 'Student Mode';
      if (batch == 'Unknown') batch = 'Student Mode';

      final contact = StorageService.getUserIdentifier() ?? profile?['mobile'] ?? '';

      final lastSynced = StorageService.getLastSyncedAt();
      String lastText = 'Never';
      if (lastSynced != null) {
        lastText = DateFormat('MMM d, h:mm a').format(lastSynced);
      }

      setState(() {
        _displayName = dispName;
        _initials = initials;
        _rollNumber = roll;
        _degreeYearText = batch;
        _batchCode = batch;
        _registeredContact = contact;
        _lastSyncedText = lastText;
        _notificationsEnabled = StorageService.isNotificationsEnabled();
        _remindersEnabled = StorageService.isClassRemindersEnabled();
        
        _timetableChangesEnabled = StorageService.isTimetableChangesEnabled();
        _roomChangesEnabled = StorageService.isRoomChangesEnabled();
        _facultyChangesEnabled = StorageService.isFacultyChangesEnabled();
        _cancelledClassesEnabled = StorageService.isCancelledClassesEnabled();
        _generalAnnouncementsEnabled = StorageService.isGeneralAnnouncementsEnabled();
      });
    }
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
                
                // ModeSelectionScreen handles cancellation of the outgoing mode's notifications
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
    
    // Update FCM preferences
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await ApiService.updatePreferences(fcmToken, val);
      }
    } catch (e) {
      debugPrint('Failed to update FCM preferences: $e');
    }
  }

  void _toggleReminders(bool val) async {
    setState(() => _remindersEnabled = val);
    await StorageService.setClassRemindersEnabled(val);
    if (val) {
      final list = StorageService.getTimetableCache();
      if (list.isNotEmpty) {
        await NotificationService.reconcileReminders();
      }
    } else {
      if (StorageService.getUserMode() == 'faculty') {
        await NotificationService.clearModeReminders('faculty');
      } else {
        await NotificationService.clearModeReminders('student');
      }
    }
  }
  
  void _toggleSetting(String key, bool val) async {
    switch (key) {
      case 'timetable':
        setState(() => _timetableChangesEnabled = val);
        await StorageService.setTimetableChangesEnabled(val);
        break;
      case 'room':
        setState(() => _roomChangesEnabled = val);
        await StorageService.setRoomChangesEnabled(val);
        break;
      case 'faculty':
        setState(() => _facultyChangesEnabled = val);
        await StorageService.setFacultyChangesEnabled(val);
        break;
      case 'cancelled':
        setState(() => _cancelledClassesEnabled = val);
        await StorageService.setCancelledClassesEnabled(val);
        break;
      case 'general':
        setState(() => _generalAnnouncementsEnabled = val);
        await StorageService.setGeneralAnnouncementsEnabled(val);
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                  left: AppConstants.paddingContainer,
                  right: AppConstants.paddingContainer,
                  bottom: 20,
                ),
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
                          textAlign: TextAlign.center,
                        ),
                        if (_rollNumber.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppConstants.primaryContainer.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppConstants.primary.withOpacity(0.25)),
                            ),
                            child: Text(
                              'Roll No: $_rollNumber',
                              style: AppConstants.getMonoLabel(color: AppConstants.primary).copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        if (_batchCode.isNotEmpty && _batchCode != 'Student Mode') ...[
                          const SizedBox(height: 6),
                          Text(
                            'Batch: $_batchCode',
                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                          ),
                        ] else if (_degreeYearText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _degreeYearText,
                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                          ),
                        ],
                        if (_registeredContact.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Registered: $_registeredContact',
                            style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                          ),
                        ],
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
                        SwitchListTile(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          title: Text('Push Notifications', style: AppConstants.getBodyLarge()),
                          subtitle: Text('Get notified of timetable updates.', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                          activeThumbColor: AppConstants.primary,
                        ),
                        if (_notificationsEnabled) ...[
                          const Divider(height: 1, indent: 16, endIndent: 16, color: AppConstants.outline),
                          SwitchListTile(
                            value: _timetableChangesEnabled,
                            onChanged: (val) => _toggleSetting('timetable', val),
                            title: Text('Timetable Changes', style: AppConstants.getBodyLarge()),
                            activeThumbColor: AppConstants.primary,
                          ),
                          SwitchListTile(
                            value: _roomChangesEnabled,
                            onChanged: (val) => _toggleSetting('room', val),
                            title: Text('Room Changes', style: AppConstants.getBodyLarge()),
                            activeThumbColor: AppConstants.primary,
                          ),
                          SwitchListTile(
                            value: _facultyChangesEnabled,
                            onChanged: (val) => _toggleSetting('faculty', val),
                            title: Text('Faculty Changes', style: AppConstants.getBodyLarge()),
                            activeThumbColor: AppConstants.primary,
                          ),
                          SwitchListTile(
                            value: _cancelledClassesEnabled,
                            onChanged: (val) => _toggleSetting('cancelled', val),
                            title: Text('Cancelled Classes', style: AppConstants.getBodyLarge()),
                            activeThumbColor: AppConstants.primary,
                          ),
                          SwitchListTile(
                            value: _generalAnnouncementsEnabled,
                            onChanged: (val) => _toggleSetting('general', val),
                            title: Text('General Announcements', style: AppConstants.getBodyLarge()),
                            activeThumbColor: AppConstants.primary,
                          ),
                        ],
                        const Divider(height: 1, indent: 16, endIndent: 16, color: AppConstants.outline),
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

                  // Academic Account Section (Student Only)
                  if (StorageService.getUserMode() != 'faculty') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ACADEMIC ACCOUNT',
                          style: AppConstants.getLabelSmall().copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        if (StorageService.isSraapConnected())
                          Text(
                            'Connected',
                            style: AppConstants.getLabelSmall(color: AppConstants.success).copyWith(fontSize: 11),
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
                          if (!StorageService.isSraapConnected())
                            ListTile(
                              leading: const Icon(Icons.school_outlined, color: AppConstants.textSecondary),
                              title: Text('SRAAP Not Connected', style: AppConstants.getBodyLarge(color: AppConstants.textSecondary)),
                              subtitle: Text('Connect in Academic tab', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                            )
                          else ...[
                            ListTile(
                              leading: const Icon(Icons.sync, color: AppConstants.primary),
                              title: Text('Refresh Academic Data', style: AppConstants.getBodyLarge()),
                              trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                              onTap: () async {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshing...')));
                                await SraapAcademicService.instance.getAcademicData(forceRefresh: true);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshed.')));
                                  setState(() {});
                                }
                              },
                            ),
                            const Divider(height: 1, color: AppConstants.outline),
                            ListTile(
                              leading: const Icon(Icons.logout, color: AppConstants.error),
                              title: Text('Disconnect SRAAP', style: AppConstants.getBodyLarge(color: AppConstants.error)),
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Disconnect SRAAP?'),
                                    content: const Text('This will clear your academic cache and disconnect your SRAAP session. Timetable and app settings will not be affected.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Disconnect', style: TextStyle(color: AppConstants.error)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await SraapAcademicService.instance.disconnect();
                                  if (mounted) setState(() {});
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

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
                        ListTile(
                          leading: const Icon(Icons.sync, color: AppConstants.primary),
                          title: Text('Sync Center', style: AppConstants.getBodyLarge()),
                          trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SyncCenterScreen()));
                          },
                        ),
                        const Divider(height: 1, color: AppConstants.outline),
                        ListTile(
                          leading: const Icon(Icons.shop, color: AppConstants.primary),
                          title: Text('Check for app update', style: AppConstants.getBodyLarge()),
                          subtitle: Text('Get the latest version from Google Play', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                          trailing: const Icon(Icons.open_in_new, color: AppConstants.textSecondary, size: 20),
                          onTap: _onCheckAppUpdate,
                        ),
                        const Divider(height: 1, color: AppConstants.outline),
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
                        const Divider(height: 1, color: AppConstants.outline),
                        ListTile(
                          leading: const Icon(Icons.logout, color: AppConstants.error),
                          title: Text('Logout', style: AppConstants.getBodyLarge(color: AppConstants.error)),
                          onTap: _isRefreshing ? null : _onLogout,
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
                          'SRU Timetable 3.0',
                          style: AppConstants.getLabelSmall(color: AppConstants.primary).copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Build: Production',
                          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version: $_currentVersion',
                          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                        ),
                        const SizedBox(height: 8),
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

  Future<void> _onLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of SRU Timetable?'),
        content: const Text('Your locally cached timetable will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out', style: TextStyle(color: AppConstants.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthRepository.instance.logout();
      await StorageService.fullLogout();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ModeSelectionScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _onCheckAppUpdate() async {
    const url = 'https://play.google.com/store/apps/details?id=com.srutimetable.mobile';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Play Store.')),
        );
      }
    }
  }
}
