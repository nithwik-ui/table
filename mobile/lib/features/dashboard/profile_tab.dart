import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme_controller.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import '../../core/notifications.dart';
import '../../core/sync.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../onboarding/mode_selection_screen.dart';
import 'sync_center_screen.dart';
import '../../core/sraap/sraap_academic_service.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/timetable/timetable_repository.dart';
import '../onboarding/sru_login_screen.dart';
import '../../core/auth/secure_session_store.dart';
import '../../core/update/update_service.dart';
import '../../core/update/app_update_policy.dart';
import '../../core/update/play_update_service.dart';
import '../../widgets/update_dialog.dart';
import 'dashboard_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String _initials = 'S';
  String _displayName = 'Student';
  String _departmentBranch = '';
  String _semesterText = '';
  String _batchCode = '';
  String _rollNumber = '';
  String _registeredContact = '';
  String _lastSyncedText = 'Never';
  
  bool _notificationsEnabled = true;
  int _reminderMinutes = 15;
  bool _isRefreshing = false;
  bool _isCheckingUpdate = false;
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
    UpdateService.instance.playStateNotifier.addListener(_onPlayUpdateStateChanged);
    ThemeController.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onPlayUpdateStateChanged() {
    if (!mounted) return;
    if (UpdateService.instance.playStateNotifier.value == InAppUpdateState.downloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Update ready. Restart to finish installing.'),
          duration: const Duration(seconds: 15),
          action: SnackBarAction(
            label: 'Restart',
            textColor: Colors.amber,
            onPressed: () {
              UpdateService.instance.completeFlexibleUpdate();
            },
          ),
        ),
      );
    }
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
    UpdateService.instance.playStateNotifier.removeListener(_onPlayUpdateStateChanged);
    ThemeController.instance.removeListener(_onThemeChanged);
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
        dispName = profile['name']!.toString().trim();
        if (dispName.isNotEmpty) {
          initials = dispName.substring(0, 1).toUpperCase();
        }
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
        _reminderMinutes = StorageService.getClassReminderMinutes();
        
        _timetableChangesEnabled = StorageService.isTimetableChangesEnabled();
        _roomChangesEnabled = StorageService.isRoomChangesEnabled();
        _facultyChangesEnabled = StorageService.isFacultyChangesEnabled();
        _cancelledClassesEnabled = StorageService.isCancelledClassesEnabled();
        _generalAnnouncementsEnabled = StorageService.isGeneralAnnouncementsEnabled();

        if (profile != null) {
          _departmentBranch = profile['department']?.toString() ?? 'Faculty Mode';
          _batchCode = profile['id']?.toString() ?? '';
          _semesterText = '';
        } else {
          _departmentBranch = 'Faculty Mode';
          _batchCode = '';
          _semesterText = '';
        }
      });
    } else {
      final profile = StorageService.getProfile();
      final sraapCache = StorageService.getSraapAcademicCache();
      final sraapProfile = sraapCache?['profile'] as Map?;
      
      String dispName = profile?['name']?.toString().trim() ??
          sraapProfile?['name']?.toString().trim() ??
          StorageService.getUserName() ??
          'Student';
      if (dispName.isEmpty) dispName = 'Student';
      String initials = dispName.isNotEmpty ? dispName.substring(0, 1).toUpperCase() : 'S';

      String roll = profile?['roll_number']?.toString() ??
          profile?['roll_no']?.toString() ??
          sraapProfile?['roll_no']?.toString() ??
          profile?['id']?.toString() ??
          StorageService.getStudentRollNumber() ??
          '';
      if (roll == 'Unknown' || roll.isEmpty) {
        final id = StorageService.getUserIdentifier() ?? '';
        if (RegExp(r'\b2[0-9][0-9A-Za-z]{2}[A-Za-z0-9]{6}\b').hasMatch(id)) {
          roll = id;
        }
      }

      String dept = sraapProfile?['branch']?.toString() ??
          profile?['department']?.toString() ??
          profile?['batch']?.toString() ??
          'CSE / Engineering';
      if (dept == 'Unknown') dept = 'Student Mode';

      String sem = sraapProfile?['semester']?.toString() ??
          profile?['semester']?.toString() ??
          '';
      String batch = profile?['batch']?.toString() ?? '';
      if (batch == 'Unknown') batch = '';

      final contact = StorageService.getUserIdentifier() ?? profile?['mobile']?.toString() ?? '';

      final lastSynced = StorageService.getLastSyncedAt();
      String lastText = 'Never';
      if (lastSynced != null) {
        lastText = DateFormat('MMM d, h:mm a').format(lastSynced);
      }

      setState(() {
        _displayName = dispName;
        _initials = initials;
        _rollNumber = roll;
        _departmentBranch = dept;
        _semesterText = sem;
        _batchCode = batch;
        _registeredContact = contact;
        _lastSyncedText = lastText;
        _notificationsEnabled = StorageService.isNotificationsEnabled();
        _reminderMinutes = StorageService.getClassReminderMinutes();
        
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
      builder: (BuildContext dialogContext) {
        final isFaculty = StorageService.getUserMode() == 'faculty';
        final targetMode = isFaculty ? 'Student' : 'Faculty';
        final targetRole = isFaculty ? 'student' : 'faculty';
        return AlertDialog(
          backgroundColor: AppConstants.surface,
          title: Text('Switch to $targetMode?', style: AppConstants.getHeadline()),
          content: Text(
            'This will switch your timetable mode to $targetMode. Your existing configurations will be saved.',
            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                final targetSession = await SecureSessionStore.getSession(role: targetRole);
                final hasValidTargetSession = targetSession != null &&
                    targetSession['cookie'] != null &&
                    (targetSession['cookie'] as String).trim().isNotEmpty;
                
                if (hasValidTargetSession) {
                  await StorageService.setUserMode(targetRole);
                  await AuthRepository.instance.restoreSession(targetRole: targetRole);
                  TimetableRepository.instance.loadFromCache();
                  await NotificationService.reconcileReminders();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 0)),
                      (route) => false,
                    );
                  }
                } else {
                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => SruLoginScreen(role: targetRole)),
                    );
                  }
                }
              },
              child: Text('Switch', style: TextStyle(color: AppConstants.primary)),
            ),
          ],
        );
      },
    );
  }

  void _toggleNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    await StorageService.setNotificationsEnabled(val);
    
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await ApiService.updatePreferences(fcmToken, val);
      }
    } catch (e) {
      debugPrint('Failed to update FCM preferences: $e');
    }
  }

  Future<void> _setReminderLeadMinutes(int minutes) async {
    setState(() {
      _reminderMinutes = minutes;
    });
    await StorageService.setClassReminderMinutes(minutes);
    if (minutes > 0) {
      final list = TimetableRepository.instance.classes.isNotEmpty
          ? TimetableRepository.instance.classes
          : StorageService.getTimetableCache();
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

  Widget _buildIdentityRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: AppConstants.getBodyMedium().copyWith(
                fontWeight: FontWeight.w600,
                color: AppConstants.textPrimary,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String label, String modeKey, IconData icon) {
    final isSelected = ThemeController.instance.themeModeString == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          ThemeController.instance.setThemeModeFromString(modeKey);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primary.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppConstants.primary : AppConstants.outline,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppConstants.primary : AppConstants.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppConstants.getLabelSmall(
                  color: isSelected ? AppConstants.primary : AppConstants.textPrimary,
                ).copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderRadioTile(String title, int minutes) {
    final isSelected = _reminderMinutes == minutes;
    return InkWell(
      onTap: () => _setReminderLeadMinutes(minutes),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? AppConstants.primary : AppConstants.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppConstants.getBodyMedium().copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: AppConstants.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = StorageService.getUserMode() != 'faculty';

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
                  bottom: 24,
                ),
                children: [
                  const SizedBox(height: 12),
                  // Profile 2.0 Student Identity Card (Section 22)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppConstants.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                      boxShadow: AppConstants.shadowLevel1,
                      border: Border.all(color: AppConstants.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppConstants.secondaryContainer,
                              child: Text(
                                _initials,
                                style: AppConstants.getDisplay(color: AppConstants.primary).copyWith(fontSize: 22),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isStudent ? 'STUDENT' : 'FACULTY',
                                    style: AppConstants.getMonoLabel(color: AppConstants.primary).copyWith(
                                      fontSize: 10.5,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _displayName,
                                    style: AppConstants.getHeadline().copyWith(fontSize: 19),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: AppConstants.outline),
                        const SizedBox(height: 12),
                        _buildIdentityRow('Name', _displayName),
                        if (_rollNumber.isNotEmpty)
                          _buildIdentityRow('Roll No', _rollNumber),
                        if (_departmentBranch.isNotEmpty)
                          _buildIdentityRow('Department / Branch', _departmentBranch),
                        if (_semesterText.isNotEmpty)
                          _buildIdentityRow('Semester', _semesterText)
                        else if (_batchCode.isNotEmpty && _batchCode != _departmentBranch)
                          _buildIdentityRow('Batch', _batchCode),
                        if (_registeredContact.isNotEmpty)
                          _buildIdentityRow('Contact', _registeredContact),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // APPEARANCE Section (Section 20)
                  Text(
                    'APPEARANCE',
                    style: AppConstants.getLabelSmall(color: AppConstants.textSecondary).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppConstants.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                      boxShadow: AppConstants.shadowLevel1,
                      border: Border.all(color: AppConstants.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme Preference',
                          style: AppConstants.getBodyLarge().copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose System default, Light mode, or Dark mode.',
                          style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildThemeOption('System', 'system', Icons.brightness_auto_rounded),
                            const SizedBox(width: 8),
                            _buildThemeOption('Light', 'light', Icons.light_mode_outlined),
                            const SizedBox(width: 8),
                            _buildThemeOption('Dark', 'dark', Icons.dark_mode_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // NOTIFICATIONS & CLASS REMINDERS Section (Section 11)
                  Text(
                    'NOTIFICATIONS',
                    style: AppConstants.getLabelSmall(color: AppConstants.textSecondary).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          title: Text('Push Notifications', style: AppConstants.getBodyLarge()),
                          subtitle: Text('Get notified of timetable updates.', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                          activeThumbColor: AppConstants.primary,
                        ),
                        if (_notificationsEnabled) ...[
                          Divider(height: 1, indent: 16, endIndent: 16, color: AppConstants.outline),
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
                        Divider(height: 1, indent: 16, endIndent: 16, color: AppConstants.outline),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Class reminders',
                                style: AppConstants.getBodyLarge().copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Alert with Subject, Room, and Start time before class.',
                                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        _buildReminderRadioTile('OFF', 0),
                        _buildReminderRadioTile('15 minutes before', 15),
                        _buildReminderRadioTile('30 minutes before', 30),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Academic Account Section (Student Only)
                  if (isStudent) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ACCOUNT & ACADEMIC',
                          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
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
                              leading: Icon(Icons.school_outlined, color: AppConstants.textSecondary),
                              title: Text('SRAAP Not Connected', style: AppConstants.getBodyLarge(color: AppConstants.textSecondary)),
                              subtitle: Text('Connect in Academic tab', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                            )
                          else ...[
                            ListTile(
                              leading: Icon(Icons.sync, color: AppConstants.primary),
                              title: Text('Refresh Academic Data', style: AppConstants.getBodyLarge()),
                              trailing: Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.showSnackBar(const SnackBar(content: Text('Refreshing...')));
                                await SraapAcademicService.instance.getAcademicData(forceRefresh: true);
                                if (!mounted) return;
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(const SnackBar(content: Text('Refreshed.')));
                                _loadProfileData();
                              },
                            ),
                            Divider(height: 1, color: AppConstants.outline),
                            ListTile(
                              leading: Icon(Icons.logout, color: AppConstants.error),
                              title: Text('Disconnect SRAAP', style: AppConstants.getBodyLarge(color: AppConstants.error)),
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AppConstants.surface,
                                    title: Text('Disconnect SRAAP?', style: AppConstants.getHeadline()),
                                    content: Text(
                                      'This will clear your academic cache and disconnect your SRAAP session. Timetable and app settings will not be affected.',
                                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text('Disconnect', style: TextStyle(color: AppConstants.error)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await SraapAcademicService.instance.disconnect();
                                  if (mounted) _loadProfileData();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // SYNC & UPDATE Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SYNC & UPDATE',
                        style: AppConstants.getLabelSmall(color: AppConstants.textSecondary).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
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
                          leading: Icon(Icons.sync, color: AppConstants.primary),
                          title: Text('Sync Center', style: AppConstants.getBodyLarge()),
                          trailing: Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SyncCenterScreen()));
                          },
                        ),
                        Divider(height: 1, color: AppConstants.outline),
                        ListTile(
                          leading: Icon(Icons.system_update_alt, color: AppConstants.primary),
                          title: Text('Check for updates', style: AppConstants.getBodyLarge()),
                          subtitle: Text('Version $_currentVersion', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                          trailing: _isCheckingUpdate
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                          onTap: _isCheckingUpdate ? null : _onCheckAppUpdate,
                        ),
                        Divider(height: 1, color: AppConstants.outline),
                        ListTile(
                          leading: Icon(
                            StorageService.getUserMode() == 'faculty' ? Icons.school_outlined : Icons.person_outline,
                            color: AppConstants.purpleAccent,
                          ),
                          title: Text(
                            StorageService.getUserMode() == 'faculty' ? 'Switch to student' : 'Switch to faculty',
                            style: AppConstants.getBodyLarge(color: AppConstants.purpleAccent),
                          ),
                          trailing: Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                          onTap: _isRefreshing ? null : _onSwitchMode,
                        ),
                        Divider(height: 1, color: AppConstants.outline),
                        ListTile(
                          leading: Icon(Icons.logout, color: AppConstants.error),
                          title: Text('Logout', style: AppConstants.getBodyLarge(color: AppConstants.error)),
                          onTap: _isRefreshing ? null : _onLogout,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ABOUT / App version
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'SRU Timetable 3.1.4',
                          style: AppConstants.getLabelSmall(color: AppConstants.primary).copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Build: Production (35)',
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
        backgroundColor: AppConstants.surface,
        title: Text('Sign out of SRU Timetable?', style: AppConstants.getHeadline()),
        content: Text(
          'Your locally cached timetable will be removed from this device.',
          style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out', style: TextStyle(color: AppConstants.error)),
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
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Checking for updates...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final result = await UpdateService.instance.checkUnifiedUpdate(isManual: true);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      if (!result.updateAvailable) {
        messenger.showSnackBar(
          const SnackBar(content: Text("You're up to date")),
        );
        return;
      }

      if (result.source == DistributionSource.googlePlay) {
        if (result.isCriticalImmediate) {
          await UpdateService.instance.performImmediateUpdate();
        } else {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => UpdateDialog(
              latestTag: result.versionTag ?? '3.1.4',
              downloadUrl: '',
              onUpdateNow: () async {
                Navigator.of(ctx).pop();
                if (result.isFlexibleAvailable) {
                  await UpdateService.instance.startFlexibleUpdate();
                } else {
                  final uri = Uri.parse('https://play.google.com/store/apps/details?id=com.srutimetable.mobile');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              onLater: () {
                UpdateService.dismissedThisSession = true;
                Navigator.of(ctx).pop();
              },
            ),
          );
        }
      } else if (result.source == DistributionSource.directApk) {
        _showDirectApkUpdateDialog(result.versionTag ?? '', result.downloadUrl ?? '');
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Update available. Please refresh the web app.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to check for updates: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showDirectApkUpdateDialog(String latestTag, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return UpdateDialog(
          latestTag: latestTag,
          downloadUrl: downloadUrl,
          onLater: () {
            UpdateService.dismissedThisSession = true;
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }
}
