import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants.dart';
import '../../core/theme_controller.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/api.dart';
import '../../core/sync.dart';
import '../../core/timetable_status_engine.dart';
import '../notifications/notifications_screen.dart';
import 'dashboard_screen.dart';
import 'free_rooms_screen.dart';
import 'timetable_search_screen.dart';
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
  String _upNextCountdown = '';
  FreePeriodSlot? _nextFreePeriod;
  List<dynamic> _todayClasses = [];
  String? _todayHolidayTitle;
  String? _todayHolidayMessage;
  List<dynamic> _announcements = [];
  
  bool _isOffline = false;
  bool _isSyncUnavailable = false;
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
    ThemeController.instance.addListener(_onThemeChanged);

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

  void _onThemeChanged() {
    if (mounted) setState(() {});
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
    ThemeController.instance.removeListener(_onThemeChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _loadLocalData() {
    final isStudent = StorageService.isStudentMode();
    final profile = StorageService.getProfile();
    final sraap = StorageService.getSraapAcademicCache();
    final sraapProfile = sraap?['profile'] as Map?;
    final name = profile?['name'] ?? sraapProfile?['name'] ?? StorageService.getUserName();
    
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
      _userName = name?.toString();
      if (isStudent) {
        final rollNo = profile?['roll_no']?.toString() ??
            sraapProfile?['roll_no']?.toString() ??
            StorageService.getStudentRollNumber() ??
            '';
        final dept = profile?['batch']?.toString() ??
            profile?['department']?.toString() ??
            sraapProfile?['branch']?.toString() ??
            'Student Mode';
        final sem = sraapProfile?['semester']?.toString() ?? profile?['semester']?.toString() ?? '';
        final parts = <String>[
          if (rollNo.isNotEmpty) rollNo,
          if (dept.isNotEmpty) dept,
          if (sem.isNotEmpty) 'Sem $sem',
        ];
        _contextLine = parts.isNotEmpty ? parts.join(' · ') : 'Student Mode';
      } else {
        _contextLine = profile?['department']?.toString() ?? 'Faculty Schedule';
      }
    });
    
    _updateFreshnessAndTimetable();
  }

  void _updateFreshnessAndTimetable() {
    final repo = TimetableRepository.instance;
    final lastSynced = repo.metadata.lastUpdated ?? StorageService.getLastSyncedAt();
    
    String computedFreshness;
    if (lastSynced == null) {
      computedFreshness = 'Never updated';
    } else {
      final diff = DateTime.now().difference(lastSynced);
      if (diff.inMinutes < 1) {
        computedFreshness = 'Updated just now';
      } else if (diff.inMinutes < 60) {
        computedFreshness = 'Updated ${diff.inMinutes} min ago';
      } else {
        final hours = diff.inHours;
        computedFreshness = 'Updated $hours hr ago';
      }
    }

    final userMode = StorageService.getUserMode() ?? 'student';
    final overrides = userMode == 'faculty'
        ? StorageService.getFacultyCalendarOverridesCache()
        : StorageService.getStudentCalendarOverridesCache();

    setState(() {
      _freshnessText = computedFreshness;
      _todayClasses = repo.todayClasses;
      _upNextClass = repo.upNextClass;
      _upNextStatus = repo.upNextStatus;
      _upNextCountdown = repo.upNextCountdown;
      _nextFreePeriod = repo.nextFreePeriod;
      _todayHolidayTitle = repo.todayHolidayTitle;
      _todayHolidayMessage = repo.todayHolidayMessage;
      _announcements = overrides.take(2).toList();
      _isSyncUnavailable = SyncService.instance.syncState != SyncState.online;
      _isOffline = repo.classes.isEmpty && _isSyncUnavailable;
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
            SnackBar(
              content: const Text('Notifications enabled successfully!'),
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

  List<Widget> _buildTodayTimelineWidgets() {
    final List<Widget> widgets = [];
    final gaps = TimetableStatusEngine.detectDayGaps(_todayClasses);

    for (int i = 0; i < _todayClasses.length; i++) {
      final c = Map<String, dynamic>.from(_todayClasses[i] as Map);
      String? itemStatus;
      String? itemCountdown;
      if (_upNextClass != null &&
          ((c['id'] != null && c['id'] == _upNextClass!['id']) ||
              (c['start_time'] == _upNextClass!['start_time'] &&
                  c['subject'] == _upNextClass!['subject']))) {
        itemStatus = _upNextStatus.isNotEmpty ? _upNextStatus : 'Up Next';
        itemCountdown = _upNextCountdown;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TimetableCard(
            classEvent: c,
            status: itemStatus,
            countdownText: itemCountdown,
            isToday: true,
            referenceDate: TimeUtils.nowInSruTime(),
          ),
        ),
      );

      final endStr = c['end_time']?.toString() ?? '';
      for (final gap in gaps) {
        if (gap.startTime == endStr) {
          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: gap.isLunch ? AppConstants.practicalBg : AppConstants.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: gap.isLunch
                      ? AppConstants.practicalAccent.withValues(alpha: 0.3)
                      : AppConstants.outline,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        gap.isLunch ? Icons.restaurant_rounded : Icons.schedule_rounded,
                        size: 15,
                        color: gap.isLunch ? AppConstants.practicalAccent : AppConstants.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        gap.isLunch ? 'LUNCH BREAK' : 'FREE PERIOD',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: gap.isLunch ? AppConstants.practicalText : AppConstants.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${TimeUtils.format12Hour(gap.startTime)} – ${TimeUtils.format12Hour(gap.endTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: gap.isLunch ? AppConstants.practicalText : AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
          break;
        }
      }
    }
    return widgets;
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
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: AppConstants.textPrimary, size: 24),
                    tooltip: 'Search Timetable',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const TimetableSearchScreen()),
                      );
                    },
                  ),
                  if (StorageService.isStudentMode())
                    IconButton(
                      icon: Icon(Icons.door_front_door_outlined, color: AppConstants.textPrimary, size: 25),
                      tooltip: 'Free Classrooms',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const FreeRoomsScreen()),
                        );
                      },
                    ),
                  if (StorageService.isStudentMode())
                    IconButton(
                      icon: Icon(Icons.history_outlined, color: AppConstants.textPrimary, size: 24),
                      tooltip: 'Changes',
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
                  IconButton(
                    icon: Icon(Icons.notifications_none, color: AppConstants.textPrimary, size: 24),
                    tooltip: 'Announcements & Notifications',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Stale / Sync Unavailable banner when no cache exists
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
                      Icon(Icons.cloud_off, color: AppConstants.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (SyncService.instance.syncState == SyncState.sessionExpired ||
                                      AuthRepository.instance.state == AuthState.sessionExpired)
                                  ? 'Session expired'
                                  : 'Offline · Showing saved timetable',
                              style: AppConstants.getHeadline().copyWith(fontSize: 14, color: AppConstants.error),
                            ),
                            Text(
                              'Last ${_freshnessText.toLowerCase()}',
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
                      Icon(Icons.event_busy, color: AppConstants.info, size: 20),
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
                    // Greeting & Student info
                    Text(
                      _userName != null && _userName!.isNotEmpty ? '$_greeting, $_userName' : _greeting,
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
                            Icon(Icons.notifications_active_outlined, color: AppConstants.primary, size: 22),
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
                              icon: Icon(Icons.close, size: 14, color: AppConstants.textSecondary),
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
                    const SizedBox(height: 14),
                    
                    // Sync status row
                    Row(
                      children: [
                        Icon(
                          _isSyncUnavailable ? Icons.cloud_off_outlined : Icons.sync,
                          color: _isSyncUnavailable ? AppConstants.warningText : AppConstants.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isSyncUnavailable && TimetableRepository.instance.classes.isNotEmpty
                                ? 'Offline · Showing saved timetable · Last ${_freshnessText.toLowerCase()}'
                                : _freshnessText,
                            style: AppConstants.getLabelSmall(
                              color: _isSyncUnavailable ? AppConstants.warningText : AppConstants.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isRefreshing) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppConstants.textSecondary),
                          )
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Announcements Banner (Section 17)
                    if (_announcements.isNotEmpty) ...[
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppConstants.surface,
                            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                            border: Border.all(color: AppConstants.outline),
                            boxShadow: AppConstants.shadowLevel1,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.campaign_outlined, size: 18, color: AppConstants.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Announcements',
                                        style: AppConstants.getHeadline().copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.chevron_right_rounded, size: 18, color: AppConstants.textSecondary),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Important · ${_announcements.first['title'] ?? 'Schedule update'}',
                                style: AppConstants.getBodyMedium().copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _announcements.first['override_date']?.toString() ?? 'Today',
                                style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

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
                        countdownText: _upNextCountdown,
                        isFeatured: true,
                        isToday: true,
                        referenceDate: TimeUtils.nowInSruTime(),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          border: Border.all(color: AppConstants.outline),
                          boxShadow: AppConstants.shadowLevel1,
                        ),
                        child: _todayClasses.isNotEmpty
                            ? Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: AppConstants.success, size: 28),
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

                    // Next Free Period Intelligence Pill (Section 12)
                    if (_nextFreePeriod != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppConstants.outline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.free_breakfast_outlined, size: 16, color: AppConstants.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Next free period · ${TimeUtils.format12Hour(_nextFreePeriod!.startTime)} – ${TimeUtils.format12Hour(_nextFreePeriod!.endTime)} (${_nextFreePeriod!.durationMinutes}m)',
                                style: AppConstants.getBodyMedium().copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.textSecondary,
                                ),
                              ),
                            ),
                          ],
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
                      ..._buildTodayTimelineWidgets(),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          border: Border.all(color: AppConstants.outline),
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
