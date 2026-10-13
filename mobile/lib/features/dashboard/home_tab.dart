import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/api.dart';
import '../../core/sync.dart';
import '../../core/timetable_status_engine.dart';
import '../notifications/notifications_screen.dart';
import 'dashboard_screen.dart';
import 'free_rooms_screen.dart';
import 'changes_tab.dart';
import 'widgets/live_class_progress.dart';
import '../../widgets/class_details_bottom_sheet.dart';
import '../../core/timetable/timetable_repository.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_state.dart';

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
                              (SyncService.instance.syncState == SyncState.sessionExpired &&
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
                          TimetableRepository.instance.refresh(force: true);
                        },
                        child: Text(
                          'Try again',
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
                      style: AppConstants.getHeadline().copyWith(fontSize: 16, color: AppConstants.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    if (_upNextClass != null) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel2,
                          border: Border.all(color: AppConstants.primary.withValues(alpha: 0.15)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => ClassDetailsBottomSheet(
                                  classEvent: _upNextClass!,
                                  status: _upNextStatus,
                                  dateStr: DateFormat('EEEE, d MMMM').format(TimeUtils.getKolkataTime()),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                            // State Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _upNextStatus == 'Ongoing' 
                                    ? AppConstants.successContainer 
                                    : AppConstants.infoContainer,
                                borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                              ),
                              child: Text(
                                _upNextStatus,
                                style: AppConstants.getLabelSmall(
                                  color: _upNextStatus == 'Ongoing' 
                                      ? AppConstants.success 
                                      : AppConstants.info
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _upNextClass!['subject'] as String? ?? 'No Subject',
                              style: AppConstants.getHeadline().copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: AppConstants.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  '${TimeUtils.format12Hour(_upNextClass!['start_time'] as String? ?? '00:00')} - ${TimeUtils.format12Hour(_upNextClass!['end_time'] as String? ?? '00:00')}',
                                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                LiveClassProgressIndicator(
                                  startTime: _upNextClass!['start_time'] as String? ?? '00:00',
                                  endTime: _upNextClass!['end_time'] as String? ?? '00:00',
                                  isToday: true,
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.place_outlined, size: 16, color: AppConstants.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  (_upNextClass!['room'] as String? ?? 'No Room').split('_')[0],
                                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                ),
                              ],
                            ),
                            if (_upNextClass!['faculty'] != null && (_upNextClass!['faculty'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: AppConstants.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _upNextClass!['faculty'] as String? ?? '',
                                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
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
                          style: AppConstants.getHeadline().copyWith(fontSize: 16, color: AppConstants.textSecondary),
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
                          final room = (c['room'] as String? ?? 'No Room').split('_')[0];
                          final ltp = c['ltp'] as String? ?? '';
                          final isLab = ltp.toLowerCase().contains('lab') || ltp.toLowerCase().contains('practical') || ltp == 'P';
                          final isCancelled = c['isCancelled'] == true;

                          final nowLocal = TimeUtils.nowInSruTime();
                          final classStatus = TimetableStatusEngine.getStatus(
                            classData: c,
                            referenceDate: nowLocal,
                            nowLocal: nowLocal,
                          );

                          String itemStatus;
                          Color statusColor;
                          Color statusBg;
                          bool isCompleted = classStatus == ClassStatus.completed;
                          bool isOngoing = classStatus == ClassStatus.ongoing;

                          if (classStatus == ClassStatus.cancelled) {
                            itemStatus = 'Cancelled';
                            statusColor = AppConstants.error;
                            statusBg = AppConstants.errorContainer;
                          } else if (classStatus == ClassStatus.ongoing) {
                            itemStatus = 'Ongoing';
                            statusColor = AppConstants.success;
                            statusBg = AppConstants.successContainer;
                          } else if (classStatus == ClassStatus.completed) {
                            itemStatus = 'Completed';
                            statusColor = AppConstants.textSecondary;
                            statusBg = AppConstants.outline.withValues(alpha: 0.12);
                          } else if (_upNextClass != null && ((c['id'] != null && c['id'] == _upNextClass!['id']) || (c['start_time'] == _upNextClass!['start_time'] && c['subject'] == _upNextClass!['subject']))) {
                            itemStatus = _upNextStatus.isNotEmpty ? _upNextStatus : 'Up Next';
                            statusColor = AppConstants.info;
                            statusBg = AppConstants.infoContainer;
                          } else {
                            itemStatus = 'Scheduled';
                            statusColor = AppConstants.primary;
                            statusBg = AppConstants.primaryContainer.withValues(alpha: 0.35);
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: isCancelled 
                                  ? AppConstants.surface.withValues(alpha: 0.5) 
                                  : (isCompleted ? AppConstants.surface.withValues(alpha: 0.85) : AppConstants.surface),
                              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                              boxShadow: isCancelled ? null : AppConstants.shadowLevel1,
                              border: isCancelled 
                                  ? Border.all(color: AppConstants.outline) 
                                  : (isOngoing ? Border.all(color: AppConstants.success.withValues(alpha: 0.4), width: 1.5) : null),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => ClassDetailsBottomSheet(
                                      classEvent: c,
                                      status: itemStatus,
                                      dateStr: DateFormat('EEEE, d MMMM').format(TimeUtils.getKolkataTime()),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Left accent type bar
                                      Container(
                                        width: 4,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: isCancelled 
                                              ? AppConstants.textSecondary.withValues(alpha: 0.3) 
                                              : (isOngoing 
                                                  ? AppConstants.success 
                                                  : (isCompleted 
                                                      ? AppConstants.textSecondary.withValues(alpha: 0.25) 
                                                      : (isLab ? AppConstants.warning : AppConstants.primary))),
                                          borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c['subject'] as String? ?? 'No Subject',
                                              style: AppConstants.getHeadline().copyWith(
                                                fontSize: 16,
                                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                color: (isCancelled || isCompleted) ? AppConstants.textSecondary : null,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  '${TimeUtils.format12Hour(c['start_time'] as String? ?? '00:00')} - ${TimeUtils.format12Hour(c['end_time'] as String? ?? '00:00')}',
                                                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(
                                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                if (!isCancelled && isOngoing) ...[
                                                  LiveClassProgressIndicator(
                                                    startTime: c['start_time'] as String? ?? '00:00',
                                                    endTime: c['end_time'] as String? ?? '00:00',
                                                    isToday: true,
                                                    referenceDate: DateTime.now(),
                                                  ),
                                                  const SizedBox(width: 10),
                                                ],
                                                Text(
                                                  isCancelled ? 'Cancelled' : room,
                                                  style: AppConstants.getBodyMedium(
                                                    color: isCancelled ? AppConstants.error : AppConstants.textSecondary
                                                  ).copyWith(
                                                    fontWeight: isCancelled ? FontWeight.bold : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Status tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                                        ),
                                        child: Text(
                                          itemStatus,
                                          style: AppConstants.getLabelSmall(
                                            color: statusColor,
                                          ).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      // LTP type badge if lab
                                      if (ltp.isNotEmpty && !isCancelled && isLab) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppConstants.warningContainer.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                                          ),
                                          child: Text(
                                            ltp,
                                            style: AppConstants.getLabelSmall(
                                              color: AppConstants.warning,
                                            ).copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
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
