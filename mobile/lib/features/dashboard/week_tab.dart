import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/theme_controller.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/sync.dart';
import '../../core/timetable_status_engine.dart';
import '../notifications/notifications_screen.dart';
import 'free_rooms_screen.dart';
import 'timetable_search_screen.dart';
import 'changes_tab.dart';
import '../../core/timetable/timetable_repository.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_state.dart';
import '../onboarding/sru_login_screen.dart';
import '../../widgets/timetable_card.dart';

enum ScheduleBlockType {
  classBlock,
  freeTime,
  lunch,
}

class ScheduleBlock {
  final ScheduleBlockType type;
  final Map<String, dynamic>? classEvent;
  final String startTime;
  final String endTime;
  final int durationMinutes;

  ScheduleBlock.classBlock({
    required this.classEvent,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  }) : type = ScheduleBlockType.classBlock;

  ScheduleBlock.freeTime({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  })  : type = ScheduleBlockType.freeTime,
        classEvent = null;

  ScheduleBlock.lunch({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  })  : type = ScheduleBlockType.lunch,
        classEvent = null;
}

class WeekTab extends StatefulWidget {
  const WeekTab({super.key});

  @override
  State<WeekTab> createState() => _WeekTabState();
}

class _WeekTabState extends State<WeekTab> {
  late DateTime _startOfWeek;
  late int _selectedDayIndex; // 0 = Mon, 6 = Sun
  
  List<dynamic> _timetable = [];
  Map<String, dynamic>? _nextClassToday;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _calculateCurrentWeek();
    _loadLocalData();
    TimetableRepository.instance.addListener(_onTimetableRepoUpdate);
    SyncService.instance.addListener(_onSyncUpdate);
    ThemeController.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onTimetableRepoUpdate() {
    if (mounted) {
      _loadLocalData();
    }
  }

  void _onSyncUpdate() {
    if (mounted) {
      if (!SyncService.instance.isSyncing) {
        _loadLocalData();
      }
    }
  }

  @override
  void dispose() {
    TimetableRepository.instance.removeListener(_onTimetableRepoUpdate);
    SyncService.instance.removeListener(_onSyncUpdate);
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _calculateCurrentWeek() {
    final nowLocal = TimeUtils.getKolkataTime();
    final weekday = nowLocal.weekday; // 1 = Mon, 7 = Sun
    _startOfWeek = DateTime(nowLocal.year, nowLocal.month, nowLocal.day).subtract(Duration(days: weekday - 1));
    _selectedDayIndex = weekday - 1;
  }

  void _loadLocalData() {
    final repo = TimetableRepository.instance;
    setState(() {
      _timetable = repo.classes;
      _isOffline = repo.classes.isEmpty && SyncService.instance.syncState != SyncState.online;
    });
    _calculateNextClassHighlight();
  }

  void _calculateNextClassHighlight() {
    if (_timetable.isEmpty) return;

    final nowLocal = TimeUtils.nowInSruTime();
    final currentDayIndex = nowLocal.weekday - 1;
    
    if (_selectedDayIndex != currentDayIndex) {
      setState(() => _nextClassToday = null);
      return;
    }

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = weekdays[currentDayIndex];
    
    final todayClasses = _timetable.where((e) => (e['day']?.toString() ?? '').toLowerCase() == currentDay.toLowerCase()).toList();

    final nextId = TimetableStatusEngine.getNextClassId(
      dayClasses: todayClasses,
      referenceDate: nowLocal,
      nowLocal: nowLocal,
    );
    
    Map<String, dynamic>? next;
    if (nextId != null) {
      next = todayClasses.firstWhere((e) => e['id'] == nextId, orElse: () => null);
    }

    setState(() {
      _nextClassToday = next;
    });
  }

  int _toMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    try {
      final parts = timeStr.split(':').map(int.parse).toList();
      return parts[0] * 60 + (parts.length > 1 ? parts[1] : 0);
    } catch (_) {
      return 0;
    }
  }

  List<ScheduleBlock> _buildTimeline(List<dynamic> classes) {
    final List<ScheduleBlock> blocks = [];
    if (classes.isEmpty) return blocks;

    int prevEndMinutes = -1;
    String prevEndTimeStr = '';

    for (int i = 0; i < classes.length; i++) {
      final c = classes[i];
      final startStr = c['start_time'] as String? ?? '';
      final endStr = c['end_time'] as String? ?? '';

      final startMins = _toMinutes(startStr);
      final endMins = _toMinutes(endStr);

      if (prevEndMinutes != -1 && startMins > prevEndMinutes) {
        final gapDuration = startMins - prevEndMinutes;
        if (gapDuration >= 10) {
          final isLunch = (prevEndMinutes >= 12 * 60 && prevEndMinutes <= 13 * 60 + 15) && gapDuration >= 30;
          if (isLunch) {
            blocks.add(ScheduleBlock.lunch(
              startTime: prevEndTimeStr,
              endTime: startStr,
              durationMinutes: gapDuration,
            ));
          } else {
            blocks.add(ScheduleBlock.freeTime(
              startTime: prevEndTimeStr,
              endTime: startStr,
              durationMinutes: gapDuration,
            ));
          }
        }
      }

      final classDuration = (endMins > startMins) ? (endMins - startMins) : 50;
      blocks.add(ScheduleBlock.classBlock(
        classEvent: c,
        startTime: startStr,
        endTime: endStr,
        durationMinutes: classDuration,
      ));

      if (endMins > prevEndMinutes) {
        prevEndMinutes = endMins;
        prevEndTimeStr = endStr;
      }
    }

    return blocks;
  }

  Widget _buildWeeklyStatsCard(WeeklyTimetableStats stats) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      padding: const EdgeInsets.all(16),
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
            children: [
              Icon(Icons.insights_rounded, size: 18, color: AppConstants.primary),
              const SizedBox(width: 8),
              Text(
                'THIS WEEK',
                style: AppConstants.getMonoLabel(color: AppConstants.primary).copyWith(
                  fontSize: 11.5,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildStatMetric('Classes', '${stats.totalClasses}')),
              Expanded(child: _buildStatMetric('Labs', '${stats.labsCount}')),
              Expanded(child: _buildStatMetric('Free periods', '${stats.freePeriodsCount}')),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppConstants.outline, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Busiest day', style: AppConstants.getLabelSmall(color: AppConstants.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      stats.busiestDay,
                      style: AppConstants.getHeadline().copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lightest day', style: AppConstants.getLabelSmall(color: AppConstants.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      stats.lightestDay,
                      style: AppConstants.getHeadline().copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppConstants.getDisplay().copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppConstants.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekdaysNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final selectedDayName = weekdaysNames[_selectedDayIndex];
    final selectedDate = _startOfWeek.add(Duration(days: _selectedDayIndex));
    
    final subHeadlineText = DateFormat('EEEE, d MMMM').format(selectedDate);
    final formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    final userMode = StorageService.getUserMode() ?? 'student';
    final isStudent = userMode == 'student';
    final overrides = userMode == 'faculty' 
        ? StorageService.getFacultyCalendarOverridesCache() 
        : StorageService.getStudentCalendarOverridesCache();

    String? holidayTitle;
    String? holidayMessage;
    List<dynamic> dayClasses = [];
    final rawToday = _timetable.where((e) => (e['day']?.toString() ?? '').toLowerCase() == selectedDayName.toLowerCase()).toList();
    for (final rawCls in rawToday) {
      final cls = Map<String, dynamic>.from(rawCls as Map);
      bool isCancelled = false;
      for (final override in overrides) {
        if (override['override_date'] == formattedDate) {
          final targetMode = override['target_mode'];
          if (targetMode == 'both' || targetMode == userMode) {
            holidayTitle = override['title'];
            holidayMessage = override['message'];
            final oStart = override['start_time'];
            final oEnd = override['end_time'];
            if (oStart != null && oStart.toString().isNotEmpty && oEnd != null && oEnd.toString().isNotEmpty) {
              final cStart = cls['start_time'] as String? ?? '00:00';
              if (cStart.compareTo(oStart) >= 0 && cStart.compareTo(oEnd) <= 0) {
                isCancelled = true;
                break;
              }
            } else {
              isCancelled = true;
              break;
            }
          }
        }
      }
      cls['isCancelled'] = isCancelled;
      dayClasses.add(cls);
    }
    dayClasses.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));

    final timelineBlocks = _buildTimeline(dayClasses);
    final weeklyStats = TimetableStatusEngine.calculateWeeklyStats(_timetable);

    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 8),
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
                  if (isStudent)
                    IconButton(
                      icon: Icon(Icons.door_front_door_outlined, color: AppConstants.textPrimary, size: 25),
                      tooltip: 'Free Classrooms',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const FreeRoomsScreen()),
                        );
                      },
                    ),
                  if (isStudent)
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
                    tooltip: 'Notifications',
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
                                  : 'Offline · No timetable available',
                              style: AppConstants.getHeadline().copyWith(fontSize: 14, color: AppConstants.error),
                            ),
                            Text(
                              'Please check your internet connection or log in.',
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
                            TimetableRepository.instance.refresh();
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
            
            // Headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 8),
              child: Text(
                'This week.',
                style: AppConstants.getDisplay().copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppConstants.textPrimary,
                ),
              ),
            ),

            // Horizontal Day Pills Row
            SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = _startOfWeek.add(Duration(days: index));
                  final isSelected = _selectedDayIndex == index;
                  
                  final shortDay = DateFormat('E').format(date).substring(0, 2);
                  final dateNum = DateFormat('d').format(date);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDayIndex = index;
                        });
                        _calculateNextClassHighlight();
                      },
                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                      child: Container(
                        width: 54,
                        decoration: BoxDecoration(
                          color: isSelected ? AppConstants.primary : AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          border: Border.all(
                            color: isSelected ? AppConstants.primary : AppConstants.outline,
                            width: isSelected ? 1.2 : 1.0,
                          ),
                          boxShadow: isSelected ? AppConstants.shadowLevel2 : AppConstants.shadowLevel1,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              shortDay,
                              style: AppConstants.getLabelSmall(
                                color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppConstants.textMuted,
                              ).copyWith(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateNum,
                              style: AppConstants.getHeadline(
                                color: isSelected ? Colors.white : AppConstants.textPrimary,
                              ).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Selected Day date Sub-headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subHeadlineText,
                    style: AppConstants.getHeadline().copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  if (holidayTitle != null)
                    Expanded(
                      child: Text(
                        holidayMessage != null && holidayMessage.isNotEmpty 
                            ? '$holidayTitle - $holidayMessage'
                            : holidayTitle,
                        style: AppConstants.getBodyMedium(color: AppConstants.infoText).copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Timeline Feed + Weekly Statistics
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppConstants.paddingContainer,
                  0,
                  AppConstants.paddingContainer,
                  MediaQuery.of(context).padding.bottom + 84,
                ),
                children: [
                  if (timelineBlocks.isNotEmpty) ...[
                    ...timelineBlocks.map((block) {
                      if (block.type == ScheduleBlockType.freeTime) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppConstants.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppConstants.outline),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppConstants.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'FREE PERIOD',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: AppConstants.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${TimeUtils.format12Hour(block.startTime)} – ${TimeUtils.format12Hour(block.endTime)} · ${block.durationMinutes} mins',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (block.type == ScheduleBlockType.lunch) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppConstants.practicalBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppConstants.practicalAccent.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.restaurant_rounded, size: 16, color: AppConstants.practicalAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lunch',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppConstants.practicalText,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${TimeUtils.format12Hour(block.startTime)} – ${TimeUtils.format12Hour(block.endTime)} · ${block.durationMinutes} mins',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.practicalText,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final c = block.classEvent!;
                      final isCancelled = c['isCancelled'] == true;
                      final isNext = !isCancelled && _nextClassToday != null &&
                          _nextClassToday!['day'] == c['day'] &&
                          _nextClassToday!['start_time'] == c['start_time'] &&
                          _nextClassToday!['subject'] == c['subject'];

                      final isTodayTab = _selectedDayIndex == TimeUtils.nowInSruTime().weekday - 1;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TimetableCard(
                          classEvent: c,
                          status: isCancelled ? 'Cancelled' : (isNext ? 'Up Next' : null),
                          dateStr: subHeadlineText,
                          isToday: isTodayTab,
                          referenceDate: selectedDate,
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          '— End of classes —',
                          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppConstants.surface,
                        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                        border: Border.all(color: AppConstants.outline),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_outlined, color: AppConstants.primary, size: 42),
                          const SizedBox(height: 12),
                          Text(
                            'No classes scheduled for $selectedDayName',
                            style: AppConstants.getHeadline().copyWith(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enjoy your free day!',
                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Weekly Statistics Card (Section 19)
                  if (_timetable.isNotEmpty) _buildWeeklyStatsCard(weeklyStats),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
