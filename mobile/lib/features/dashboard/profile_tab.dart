import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import '../onboarding/degree_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
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

  void _onResetTimetable() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Timetable?'),
          content: const Text('This will clear your current timetable selection and cache. Your username profile is kept.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                
                // Clear selection keys only (keeping userName)
                await StorageService.clearSelection();

                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const DegreeScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Reset', style: TextStyle(color: AppConstants.error)),
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
      // Mock FCM token (Phase 7 will use real tokens)
      await ApiService.updatePreferences('MOCK_DEVICE_TOKEN_PHASE_6', val);
    }
  }

  void _toggleReminders(bool val) async {
    setState(() => _remindersEnabled = val);
    await StorageService.setClassRemindersEnabled(val);
  }

  Future<void> _refreshTimetable() async {
    final selection = StorageService.getSelection();
    if (selection == null) return;
    final batchId = selection['batchId']!;

    setState(() => _isRefreshing = true);

    try {
      final list = await ApiService.fetchTimetable(batchId);
      await StorageService.saveTimetableCache(list);
      await StorageService.saveLastSyncedAt(DateTime.now());
      
      setState(() => _isRefreshing = false);
      _loadProfileData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable successfully updated!')),
        );
      }
    } catch (_) {
      setState(() => _isRefreshing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh. You are offline.')),
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
                  Text(
                    'sru',
                    style: AppConstants.getDisplay(color: AppConstants.primary).copyWith(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SRU Timetable',
                      style: AppConstants.getHeadline().copyWith(fontSize: 18),
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
                        // Ghost Link: Reset Timetable
                        TextButton(
                          onPressed: _onResetTimetable,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // About / App version
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'SRU Timetable v${AppConstants.currentVersion}',
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
    
    final release = await ApiService.fetchLatestGithubRelease();
    setState(() => _isCheckingUpdates = false);

    if (release == null) {
      if (showToast && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not check for updates. You are offline.')),
        );
      }
      return;
    }

    final String latestTag = release['tag_name'] as String? ?? '1.0.1';
    final String htmlUrl = release['html_url'] as String? ?? 'https://github.com/${AppConstants.githubRepo}';
    
    // Find apk asset url if present
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
    } else {
      if (showToast && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('App is up to date!')),
        );
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
