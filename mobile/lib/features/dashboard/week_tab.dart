import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/sync.dart';
import '../notifications/notifications_screen.dart';
import 'changes_tab.dart';
import 'widgets/live_class_progress.dart';
import '../../widgets/class_details_bottom_sheet.dart';

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
    SyncService.instance.addListener(_onSyncUpdate);
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
    SyncService.instance.removeListener(_onSyncUpdate);
    super.dispose();
  }

  void _calculateCurrentWeek() {
    // Current Local Time
    final nowLocal = DateTime.now();
    
    // Find the Monday of the current week
    final weekday = nowLocal.weekday; // 1 = Mon, 7 = Sun
    _startOfWeek = nowLocal.subtract(Duration(days: weekday - 1));
    
    // Select current day index by default (0-6)
    _selectedDayIndex = weekday - 1;
  }

  void _loadLocalData() {
    final userMode = StorageService.getUserMode();
    final cached = userMode == 'faculty'
        ? StorageService.getFacultyTimetableCache()
        : StorageService.getTimetableCache();
        
    setState(() {
      _timetable = cached;
    });
    _calculateNextClassHighlight();
  }

  void _calculateNextClassHighlight() {
    if (_timetable.isEmpty) return;

    final nowLocal = DateTime.now();
    final currentDayIndex = nowLocal.weekday - 1;
    
    // Highlight is only computed if the selected day index matches today
    if (_selectedDayIndex != currentDayIndex) {
      setState(() => _nextClassToday = null);
      return;
    }

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = weekdays[currentDayIndex];
    final currentMinutes = nowLocal.hour * 60 + nowLocal.minute;

    final todayClasses = _timetable.where((e) => e['day'] == currentDay).toList();
    todayClasses.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));

    // Find first class starting in the future
    Map<String, dynamic>? next;
    for (final c in todayClasses) {
      final startParts = (c['start_time'] as String).split(':').map(int.parse).toList();
      final startMinutes = startParts[0] * 60 + startParts[1];
      if (startMinutes > currentMinutes) {
        next = Map<String, dynamic>.from(c);
        break;
      }
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

      // Check for gap between previous class and current class
      if (prevEndMinutes != -1 && startMins > prevEndMinutes) {
        final gapDuration = startMins - prevEndMinutes;
        if (gapDuration >= 10) {
          // Detect lunch: Standard university interval between 12:00 and 13:30 with duration >= 30 mins
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

      // Add the class block
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

  @override
  Widget build(BuildContext context) {
    final weekdaysNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final selectedDayName = weekdaysNames[_selectedDayIndex];
    final selectedDate = _startOfWeek.add(Duration(days: _selectedDayIndex));
    
    // Format headers
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
    final rawToday = _timetable.where((e) => (e['day'] as String).toLowerCase() == selectedDayName.toLowerCase()).toList();
    for (final rawCls in rawToday) {
      final cls = Map<String, dynamic>.from(rawCls);
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
               final cStart = cls['start_time'] as String;
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

    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with SRU logo, Changes icon (Student only), and Notification Bell
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
                  // Changes Icon (Student Only)
                  if (isStudent)
                    IconButton(
                      icon: const Icon(Icons.history_outlined, color: AppConstants.textPrimary, size: 24),
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
                  // Notification Bell
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: AppConstants.textPrimary, size: 24),
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
                              style: AppConstants.getBodyMedium(color: AppConstants.error.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _isOffline = false);
                          SyncService.instance.syncTimetable();
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
            
            // Headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 8),
              child: Text(
                'This week.',
                style: AppConstants.getDisplay().copyWith(fontSize: 24),
              ),
            ),

            // Horizontal Day Pills Row
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = _startOfWeek.add(Duration(days: index));
                  final isSelected = _selectedDayIndex == index;
                  
                  final shortDay = DateFormat('E').format(date).substring(0, 2); // Mo, Tu, We...
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
                        width: 52,
                        decoration: BoxDecoration(
                          color: isSelected ? AppConstants.primary : AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          border: Border.all(
                            color: isSelected ? AppConstants.primary : AppConstants.outline,
                          ),
                          boxShadow: isSelected ? AppConstants.shadowLevel2 : AppConstants.shadowLevel1,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              shortDay,
                              style: AppConstants.getLabelSmall(
                                color: isSelected ? Colors.white70 : AppConstants.textSecondary,
                              ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateNum,
                              style: AppConstants.getHeadline(
                                color: isSelected ? Colors.white : AppConstants.textPrimary,
                              ).copyWith(fontSize: 16),
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
                    style: AppConstants.getHeadline().copyWith(fontSize: 16, color: AppConstants.textSecondary),
                  ),
                  if (holidayTitle != null)
                    Expanded(
                      child: Text(
                        holidayMessage != null && holidayMessage.isNotEmpty 
                            ? '$holidayTitle - $holidayMessage'
                            : holidayTitle,
                        style: AppConstants.getBodyMedium(color: AppConstants.info).copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Timeline Feed (Classes, Free Time, Lunch Time)
            Expanded(
              child: timelineBlocks.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                      itemCount: timelineBlocks.length + 1, // list + end of classes divider
                      itemBuilder: (context, index) {
                        if (index == timelineBlocks.length) {
                          // End of classes indicator
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                '— End of classes —',
                                style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                              ),
                            ),
                          );
                        }

                        final block = timelineBlocks[index];

                        // Free Time block
                        if (block.type == ScheduleBlockType.freeTime) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF94A3B8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Free Time',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${TimeUtils.format12Hour(block.startTime)} – ${TimeUtils.format12Hour(block.endTime)} · ${block.durationMinutes} mins',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Lunch block
                        if (block.type == ScheduleBlockType.lunch) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFED7AA)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.restaurant_rounded, size: 16, color: Color(0xFFEA580C)),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Lunch',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFC2410C),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${TimeUtils.format12Hour(block.startTime)} – ${TimeUtils.format12Hour(block.endTime)} · ${block.durationMinutes} mins',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9A3412),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Class block
                        final c = block.classEvent!;
                        final room = (c['room'] as String? ?? 'No Room').split('_')[0];
                        final ltp = c['ltp'] as String? ?? '';
                        final isLab = ltp.toLowerCase().contains('lab') || ltp.toLowerCase().contains('practical') || ltp == 'P';
                        final isCancelled = c['isCancelled'] == true;
                        
                        // Check if this class is the "Next" class highlighted
                        final isNext = !isCancelled && _nextClassToday != null &&
                            _nextClassToday!['day'] == c['day'] &&
                            _nextClassToday!['start_time'] == c['start_time'] &&
                            _nextClassToday!['subject'] == c['subject'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCancelled ? AppConstants.surface.withValues(alpha: 0.5) : AppConstants.surface,
                              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                              boxShadow: isCancelled ? null : AppConstants.shadowLevel1,
                              border: Border.all(
                                color: isNext ? AppConstants.primary : AppConstants.outline,
                                width: isNext ? 1.5 : 1.0,
                              ),
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
                                    builder: (ctx) => ClassDetailsBottomSheet(
                                      classEvent: c,
                                      status: isCancelled ? 'Cancelled' : (isNext ? 'Up Next' : 'Scheduled'),
                                      dateStr: subHeadlineText,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c['subject'] as String,
                                              style: AppConstants.getHeadline().copyWith(
                                                fontSize: 18,
                                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                color: isCancelled ? AppConstants.textSecondary : null,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '${TimeUtils.format12Hour(c['start_time'])} - ${TimeUtils.format12Hour(c['end_time'])}',
                                                style: AppConstants.getLabelSmall(
                                                  color: isCancelled ? AppConstants.textSecondary : AppConstants.primary
                                                ).copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (!isCancelled)
                                                LiveClassProgressIndicator(
                                                  startTime: c['start_time'] as String,
                                                  endTime: c['end_time'] as String,
                                                  isToday: _selectedDayIndex == DateTime.now().weekday - 1,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.place_outlined, size: 16, color: AppConstants.textSecondary),
                                          const SizedBox(width: 6),
                                          Text(
                                            isCancelled ? 'Cancelled' : room,
                                            style: AppConstants.getBodyMedium(
                                              color: isCancelled ? AppConstants.error : AppConstants.textSecondary
                                            ).copyWith(
                                              fontWeight: isCancelled ? FontWeight.bold : null,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          const Icon(Icons.person_outline, size: 16, color: AppConstants.textSecondary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              c['faculty'] as String? ?? 'Unknown Faculty',
                                              style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isCancelled && (isNext || ltp.isNotEmpty)) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            if (isNext)
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppConstants.primary,
                                                  borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                                                ),
                                                child: Text(
                                                  'Next',
                                                  style: AppConstants.getLabelSmall(color: Colors.white).copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            if (ltp.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isLab
                                                      ? AppConstants.warningContainer.withValues(alpha: 0.5)
                                                      : AppConstants.secondaryContainer.withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                                                ),
                                                child: Text(
                                                  ltp,
                                                  style: AppConstants.getLabelSmall(
                                                    color: isLab ? AppConstants.warning : AppConstants.textSecondary,
                                                  ).copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: AppConstants.primary, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No classes scheduled for $selectedDayName',
                          style: AppConstants.getHeadline().copyWith(fontSize: 18),
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
        ),
      ),
    );
  }
}
