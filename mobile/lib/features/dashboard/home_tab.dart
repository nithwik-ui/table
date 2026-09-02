import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import 'ad_banner.dart';
import '../../core/api.dart';
import '../../core/notifications.dart';
import '../notifications/notifications_screen.dart';
import 'dashboard_screen.dart';
import 'free_rooms_screen.dart';
import 'widgets/live_class_progress.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

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
  
  bool _isOffline = false;
  bool _isRefreshing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _refreshTimetable();
    
    // Auto-update freshness text and class statuses every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _updateFreshnessAndTimetable();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadLocalData() {
    final name = StorageService.getUserName();
    final selection = StorageService.getSelection();

    // Greeting time calculation (local timezone context)
    final nowLocal = DateTime.now();
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
      if (selection != null) {
        _contextLine = '${selection['degree']} · ${selection['year']} · ${selection['batchCode']}';
      }
    });
    
    _updateFreshnessAndTimetable();
  }

  void _updateFreshnessAndTimetable() {
    final lastSynced = StorageService.getLastSyncedAt();
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

    // Refresh timetable from cache
    final timetable = StorageService.getTimetableCache();
    if (timetable.isNotEmpty) {
      _calculateSchedules(timetable);
    }
  }

  void _calculateSchedules(List<dynamic> timetable) {
    // Current Local Time
    final nowLocal = DateTime.now();
    final weekdayIndex = nowLocal.weekday;
    
    // Mappings: Flutter weekday (1 = Mon, 7 = Sun) -> DB Day values
    final weekdays = [
      'Sunday', // 0
      'Monday', // 1
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday' // 7
    ];
    final currentDay = weekdays[weekdayIndex];
    final currentMinutes = nowLocal.hour * 60 + nowLocal.minute;

    // Filter today's classes
    final today = timetable.where((e) => e['day'] == currentDay).toList();
    
    // Sort chronologically
    today.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));

    // Calculate remaining classes (where end_time has not passed)
    final remaining = today.where((e) {
      final endParts = (e['end_time'] as String).split(':').map(int.parse).toList();
      final endMinutes = endParts[0] * 60 + endParts[1];
      return endMinutes > currentMinutes;
    }).toList();

    Map<String, dynamic>? nextClass;
    String status = '';

    if (remaining.isNotEmpty) {
      // Check if first remaining class is currently in progress
      final first = remaining.first;
      final startParts = (first['start_time'] as String).split(':').map(int.parse).toList();
      final startMinutes = startParts[0] * 60 + startParts[1];

      if (currentMinutes >= startMinutes) {
        nextClass = Map<String, dynamic>.from(first);
        status = 'Ongoing';
      } else {
        nextClass = Map<String, dynamic>.from(first);
        final diff = startMinutes - currentMinutes;
        status = 'Starts in $diff min';
      }
    }

    setState(() {
      _upNextClass = nextClass;
      _upNextStatus = status;
      // Filter out the active "Up Next" class from the remaining classes feed
      if (nextClass != null) {
        _todayClasses = remaining.skip(1).toList();
      } else {
        _todayClasses = remaining;
      }
    });
  }

  Future<void> _refreshTimetable() async {
    final selection = StorageService.getSelection();
    if (selection == null) return;
    final batchId = selection['batchId']!;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final list = await ApiService.fetchTimetable(batchId);
      await StorageService.saveTimetableCache(list);
      await StorageService.saveLastSyncedAt(DateTime.now());
      
      // FIX: Ensure alarms are explicitly rescheduled on manual refresh
      await NotificationService.scheduleClassReminders(list);
      
      setState(() {
        _isOffline = false;
        _isRefreshing = false;
      });
      _updateFreshnessAndTimetable();
    } catch (_) {
      setState(() {
        _isOffline = true;
        _isRefreshing = false;
      });
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
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Free Rooms Button (Student Only)
                  if (StorageService.getUserMode() == 'student')
                    IconButton(
                      icon: const Icon(Icons.meeting_room_outlined, color: AppConstants.textPrimary, size: 24),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const FreeRoomsScreen()),
                        );
                      },
                    ),
                  // Settings Gear (opens Profile)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppConstants.textPrimary, size: 22),
                    onPressed: () {
                      final parent = context.findAncestorStateOfType<State<DashboardScreen>>();
                      if (parent != null) {
                        // Switch to Profile Tab
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 3)),
                          (route) => false,
                        );
                      }
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
            
            // Offline banner
            if (_isOffline) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.errorContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    border: Border.all(color: AppConstants.error.withOpacity(0.3)),
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
                              'You\'re offline',
                              style: AppConstants.getHeadline().copyWith(fontSize: 14, color: AppConstants.error),
                            ),
                            Text(
                              'Showing last synchronized timetable.',
                              style: AppConstants.getBodyMedium(color: AppConstants.error.withOpacity(0.8)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _refreshTimetable,
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

            Expanded(
              child: RefreshIndicator(
                color: AppConstants.primary,
                onRefresh: _refreshTimetable,
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
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel2,
                          border: Border.all(color: AppConstants.primary.withOpacity(0.15)),
                        ),
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
                              _upNextClass!['subject'] as String,
                              style: AppConstants.getHeadline().copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: AppConstants.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  '${TimeUtils.format12Hour(_upNextClass!['start_time'])} - ${TimeUtils.format12Hour(_upNextClass!['end_time'])}',
                                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                LiveClassProgressIndicator(
                                  startTime: _upNextClass!['start_time'] as String,
                                  endTime: _upNextClass!['end_time'] as String,
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
                            if (_upNextClass!['faculty'] != null && (_upNextClass!['faculty'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: AppConstants.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _upNextClass!['faculty'] as String,
                                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ] else ...[
                      // Empty state
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel1,
                        ),
                        child: Center(
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
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 1)),
                              (route) => false,
                            );
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
                          final c = _todayClasses[index];
                          final room = (c['room'] as String? ?? 'No Room').split('_')[0];
                          final ltp = c['ltp'] as String? ?? '';
                          final isLab = ltp.toLowerCase().contains('lab') || ltp.toLowerCase().contains('practical') || ltp == 'P';

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppConstants.surface,
                              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                              boxShadow: AppConstants.shadowLevel1,
                            ),
                            child: Row(
                              children: [
                                // Left accent type bar
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isLab ? AppConstants.warning : AppConstants.primary,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['subject'] as String,
                                        style: AppConstants.getHeadline().copyWith(fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '${TimeUtils.format12Hour(c['start_time'])} - ${TimeUtils.format12Hour(c['end_time'])}',
                                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                          ),
                                          const SizedBox(width: 12),
                                          LiveClassProgressIndicator(
                                            startTime: c['start_time'] as String,
                                            endTime: c['end_time'] as String,
                                            isToday: true,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            room,
                                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // LTP type badge
                                if (ltp.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isLab 
                                          ? AppConstants.warningContainer.withOpacity(0.5) 
                                          : AppConstants.secondaryContainer.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                                    ),
                                    child: Text(
                                      ltp,
                                      style: AppConstants.getLabelSmall(
                                        color: isLab ? AppConstants.warning : AppConstants.textSecondary
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      // Empty state
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel1,
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppConstants.success, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              'Day complete',
                              style: AppConstants.getHeadline().copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No more classes today.',
                              style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const AdBanner(),
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
