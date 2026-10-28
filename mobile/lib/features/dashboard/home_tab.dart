import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/api.dart';
import '../../core/sync.dart';
import '../notifications/notifications_screen.dart';
import 'dashboard_screen.dart';
import 'free_rooms_screen.dart';
import 'changes_tab.dart';
import '../../core/timetable/timetable_repository.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_state.dart';
import '../onboarding/sru_login_screen.dart';
import '../../widgets/timetable_card.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToWeek;
  const HomeTab({super.key, this.onNavigateToWeek});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _greeting = 'Good morning';
  String? _userName;
  String _contextLine = '';
  String _freshnessText = 'Syncing...';
  
  Map<String, dynamic>? _upNextClass;
  String _upNextStatus = '';
  List<dynamic> _todayClasses = [];
  String? _todayHolidayTitle;
  String? _todayHolidayMessage;
  
  bool _isOffline = false;
  bool _isRefreshing = false;
  bool _showWebNotificationPrompt = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    
    // Auto-update freshness text and class statuses every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        TimetableRepository.instance.updateStatusCalculations();
        _updateFreshnessAndTimetable();
      }
    });
    
    TimetableRepository.instance.addListener(_onTimetableRepoUpdate);
    SyncService.instance.addListener(_onSyncUpdate);

    if (kIsWeb) {
      FirebaseMessaging.instance.getNotificationSettings().then((settings) {
        if (mounted &&
            settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional &&
            !StorageService.isWebNotificationPromptDismissed()) {
          setState(() => _showWebNotificationPrompt = true);
        }
      }).catchError((_) {});
    }
  }

  void _onTimetableRepoUpdate() {
    if (mounted) {
      _updateFreshnessAndTimetable();
    }
  }

  void _onSyncUpdate() {
    if (mounted) {
      if (!SyncService.instance.isSyncing) {
        setState(() => _isRefreshing = false);
        _updateFreshnessAndTimetable();
      } else {
        setState(() => _isRefreshing = true);
      }
    }
  }

  @override
  void dispose() {
    TimetableRepository.instance.removeListener(_onTimetableRepoUpdate);
    SyncService.instance.removeListener(_onSyncUpdate);
    _timer?.cancel();
    super.dispose();
  }

  void _loadLocalData() {
    final isStudent = StorageService.isStudentMode();
    final profile = StorageService.getProfile();
    final name = profile?['name'] ?? StorageService.getUserName();
    
    // Greeting time calculation (Kolkata timezone context)
    final nowLocal = TimeUtils.getKolkataTime();
    final hour = nowLocal.hour;
    String greet;
    if (hour < 12) {
      greet = 'Good morning';
    } else if (hour < 17) {
      greet = 'Good afternoon';
    } else {
      greet = 'Good evening';
    }

    setState(() {
      _greeting = greet;
      _userName = name;
      if (isStudent) {
        _contextLine = profile?['batch'] ?? profile?['department'] ?? 'Student Mode';
      } else {
        _contextLine = 'Faculty Schedule';
      }
    });
    
    _updateFreshnessAndTimetable();
  }

  void _updateFreshnessAndTimetable() {
    final repo = TimetableRepository.instance;
    final lastSynced = repo.metadata.lastUpdated;
    
    if (lastSynced == null) {
      setState(() {
        _freshnessText = 'Never updated';
      });
    } else {
      final diff = DateTime.now().difference(lastSynced);
      if (diff.inMinutes < 1) {
        setState(() => _freshnessText = 'Updated just now');
      } else if (diff.inMinutes < 60) {
        setState(() => _freshnessText = 'Updated ${diff.inMinutes} min ago');
      } else {
        final hours = diff.inHours;
        setState(() => _freshnessText = 'Updated $hours hr ago');
      }
    }

    setState(() {
      _todayClasses = repo.todayClasses;
      _upNextClass = repo.upNextClass;
      _upNextStatus = repo.upNextStatus;
      _todayHolidayTitle = repo.todayHolidayTitle;
      _todayHolidayMessage = repo.todayHolidayMessage;
      // Only display offline banner if there is literally NO timetable in storage
      _isOffline = repo.classes.isEmpty && SyncService.instance.syncState != SyncState.online;
    });
  }


  Future<void> _enableWebNotifications() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await FirebaseMessaging.instance.getToken(vapidKey: AppConstants.fcmVapidKey);
        if (token != null && token.isNotEmpty) {
          final userMode = StorageService.getUserMode() ?? 'student';
          final profile = StorageService.getProfile();
          final id = profile?['id']?.toString() ?? 
              profile?['roll_no']?.toString() ?? 
              StorageService.getStudentRollNumber() ?? 
              StorageService.getUserIdentifier() ?? '';
          final batchId = profile?['batch_id']?.toString() ?? '';
          await ApiService.registerDevice(
            token,
            userMode == 'student' ? (batchId.isNotEmpty ? batchId : id) : '',
            userMode: userMode,
            facultyId: userMode == 'faculty' ? id : id,
          );
        }
        if (mounted) {
          setState(() => _showWebNotificationPrompt = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications enabled successfully!'),
              backgroundColor: AppConstants.success,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _showWebNotificationPrompt = false);
          await StorageService.setWebNotificationPromptDismissed(true);
        }
      }
    } catch (e) {
      debugPrint('[HOME] Web notification enable error: $e');
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
            // Header
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingContainer),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Free Rooms Button (Student Only)
                  if (StorageService.isStudentMode())
                    IconButton(
                      icon: const Icon(Icons.door_front_door_outlined, color: AppConstants.textPrimary, size: 26),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const FreeRoomsScreen()),
                        );
                      },
                    ),
                  // Changes Icon (Student Only)
                  if (StorageService.isStudentMode())
                    IconButton(
                      icon: const Icon(Icons.history_outlined, color: AppConstants.textPrimary, size: 24),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(title: const Text('Changes'), backgroundColor: AppConstants.surface),
                              body: const SafeArea(child: ChangesTab()),
                            ),
                          ),
                        );
                      },
                    ),
                  // Notification Bell
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: AppConstants.textPrimary, size: 24),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Stale / Sync Unavailable banner (non-blocking)
            if (_isOffline) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.errorContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    border: Border.all(color: AppConstants.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: AppConstants.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (SyncService.instance.syncState == SyncState.sessionExpired ||
                                      AuthRepository.instance.state == AuthState.sessionExpired)
                                  ? 'Session expired'
                                  : 'Sync unavailable',
                              style: AppConstants.getHeadline().copyWith(fontSize: 14, color: AppConstants.error),
                            ),
                            Text(
                              'Showing saved timetable.',
                              style: AppConstants.getBodyMedium(color: AppConstants.error.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (SyncService.instance.syncState == SyncState.sessionExpired ||
                              AuthRepository.instance.state == AuthState.sessionExpired) {
                            final role = StorageService.getUserMode() ?? 'student';
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => SruLoginScreen(role: role)),
                            );
                          } else {
                            TimetableRepository.instance.refresh(force: true);
                          }
                        },
                        child: Text(
                          (SyncService.instance.syncState == SyncState.sessionExpired ||
                                  AuthRepository.instance.state == AuthState.sessionExpired)
                              ? 'Log in'
                              : 'Try again',
                          style: AppConstants.getBodyMedium(color: AppConstants.error).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Holiday banner
            if (_todayHolidayTitle != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.infoContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    border: Border.all(color: AppConstants.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_busy, color: AppConstants.info, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _todayHolidayTitle!,
                              style: AppConstants.getHeadline().copyWith(fontSize: 14, color: AppConstants.info),
                            ),
                            if (_todayHolidayMessage != null && _todayHolidayMessage!.isNotEmpty)
                              Text(
                                _todayHolidayMessage!,
                                style: AppConstants.getBodyMedium(color: AppConstants.info.withValues(alpha: 0.9)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Expanded(
              child: RefreshIndicator(
                color: AppConstants.primary,
                onRefresh: () async {
                  await TimetableRepository.instance.refresh(force: true);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // Greeting & context
                    Text(
                      _userName != null ? '$_greeting, $_userName' : _greeting,
                      style: AppConstants.getDisplay().copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _contextLine,
                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                    ),
                    if (_showWebNotificationPrompt) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          border: Border.all(color: AppConstants.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, color: AppConstants.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enable Notifications',
                                    style: AppConstants.getHeadline().copyWith(fontSize: 13, color: AppConstants.primary),
                                  ),
                                  Text(
                                    'Get live alerts when your classes or rooms are changed.',
                                    style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _enableWebNotifications,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primary,
                                foregroundColor: AppConstants.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(56, 28),
                              ),
                              child: const Text('Enable', style: TextStyle(fontSize: 11)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 14, color: AppConstants.textSecondary),
                              onPressed: () {
                                setState(() => _showWebNotificationPrompt = false);
                                StorageService.setWebNotificationPromptDismissed(true);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // Sync Refresh row
                    Row(
                      children: [
                        const Icon(Icons.sync, color: AppConstants.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _freshnessText,
                          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                        ),
                        if (_isRefreshing) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppConstants.textSecondary),
                          )
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // "Up Next" Section
                    Text(
                      'Up Next',
                      style: AppConstants.getHeadline().copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    if (_upNextClass != null) ...[
                      TimetableCard(
                        classEvent: _upNextClass!,
                        status: _upNextStatus.isNotEmpty ? _upNextStatus : 'Up Next',
                        isFeatured: true,
                        isToday: true,
                      ),
                    ] else ...[
                      // Empty state for Up Next
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel1,
                        ),
                        child: _todayClasses.isNotEmpty
                            ? Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: AppConstants.success, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Classes Completed',
                                          style: AppConstants.getHeadline().copyWith(fontSize: 15),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'All scheduled classes for today have finished.',
                                          style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Text(
                                  'No upcoming classes.',
                                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                ),
                              ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // "Today" Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today',
                          style: AppConstants.getHeadline().copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                        ),
                        TextButton(
                          onPressed: () {
                            if (widget.onNavigateToWeek != null) {
                              widget.onNavigateToWeek!();
                            } else {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 1)),
                                (route) => false,
                              );
                            }
                          },
                          child: Text(
                            'View All',
                            style: AppConstants.getBodyMedium(color: AppConstants.primary).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_todayClasses.isNotEmpty) ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _todayClasses.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final c = Map<String, dynamic>.from(_todayClasses[index] as Map);
                          String? itemStatus;
                          if (_upNextClass != null &&
                              ((c['id'] != null && c['id'] == _upNextClass!['id']) ||
                               (c['start_time'] == _upNextClass!['start_time'] &&
                                   c['subject'] == _upNextClass!['subject']))) {
                            itemStatus = _upNextStatus.isNotEmpty ? _upNextStatus : 'Up Next';
                          }

                          return TimetableCard(
                            classEvent: c,
                            status: itemStatus,
                            isToday: true,
                          );
                        },
                      ),
                    ] else ...[
                      // Empty state
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel1,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                _todayHolidayTitle != null ? Icons.celebration_outlined : Icons.calendar_today_outlined,
                                color: _todayHolidayTitle != null ? AppConstants.warning : AppConstants.primary,
                                size: 36,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _todayHolidayTitle != null ? _todayHolidayTitle! : 'No Classes Scheduled Today',
                                style: AppConstants.getHeadline().copyWith(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _todayHolidayMessage ?? 'No classes scheduled for today. Enjoy your day off!',
                                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
