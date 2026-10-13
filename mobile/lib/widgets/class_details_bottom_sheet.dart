import 'package:flutter/material.dart';
import '../core/utils.dart';
import '../core/sraap/models/sraap_academic_data.dart';
import '../core/storage.dart';
import '../features/academic/attendance_screen.dart';

class ClassDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> classEvent;
  final String status;
  final String? dateStr;

  const ClassDetailsBottomSheet({
    super.key,
    required this.classEvent,
    required this.status,
    this.dateStr,
  });

  @override
  State<ClassDetailsBottomSheet> createState() => _ClassDetailsBottomSheetState();
}

class _ClassDetailsBottomSheetState extends State<ClassDetailsBottomSheet> {
  SraapSubjectAttendance? _attendance;
  bool _isLoadingAttendance = true;
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  void _loadAttendance() {
    if (StorageService.getUserMode() != 'student') {
      setState(() {
        _isLoadingAttendance = false;
      });
      return;
    }

    final raw = StorageService.getSraapAcademicCache();
    if (raw != null) {
      try {
        final data = SraapAcademicData.fromJson(raw);
        _lastSynced = data.lastSynced;
        final timetableSubject = (widget.classEvent['subject'] as String?) ?? '';
        _attendance = _findMatchingSubject(timetableSubject, data.subjects);
      } catch (_) {}
    }

    setState(() {
      _isLoadingAttendance = false;
    });
  }

  SraapSubjectAttendance? _findMatchingSubject(String timetableSubject, List<SraapSubjectAttendance> subjects) {
    if (timetableSubject.isEmpty) return null;

    final normTimetable = _normalizeForMatch(timetableSubject);

    // 1. Exact match
    for (var s in subjects) {
      if (_normalizeForMatch(s.subjectName) == normTimetable) {
        return s;
      }
    }

    // 2. Contains match while matching lab / theory mode
    final isLab = normTimetable.contains('lab') || normTimetable.contains('practical');
    for (var s in subjects) {
      final normSraap = _normalizeForMatch(s.subjectName);
      final sraapIsLab = normSraap.contains('lab') || normSraap.contains('practical');

      if (isLab == sraapIsLab) {
        if (normSraap.contains(normTimetable) || normTimetable.contains(normSraap)) {
          return s;
        }
      }
    }

    // 3. Fallback check for acronym or partial code match
    for (var s in subjects) {
      if (s.subjectCode != null && s.subjectCode!.isNotEmpty) {
        final normCode = _normalizeForMatch(s.subjectCode!);
        if (normTimetable.contains(normCode) || normCode.contains(normTimetable)) {
          return s;
        }
      }
    }

    return null;
  }

  String _normalizeForMatch(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _calculateDuration(String? start, String? end) {
    if (start == null || end == null || start.isEmpty || end.isEmpty) return '1 hour';
    try {
      final sp = start.split(':').map(int.parse).toList();
      final ep = end.split(':').map(int.parse).toList();
      final sm = sp[0] * 60 + sp[1];
      final em = ep[0] * 60 + ep[1];
      final diff = em - sm;
      if (diff <= 0) return '50 mins';
      if (diff == 60) return '1 hour';
      if (diff > 60) {
        final hrs = diff ~/ 60;
        final mins = diff % 60;
        return mins > 0 ? '$hrs hr $mins mins' : '$hrs hours';
      }
      return '$diff minutes';
    } catch (_) {
      return '50 mins';
    }
  }

  String _formatLocation(String? roomRaw) {
    if (roomRaw == null || roomRaw.trim().isEmpty || roomRaw.toLowerCase() == 'no room') {
      return 'Room not assigned';
    }
    if (roomRaw.contains('_')) {
      final parts = roomRaw.split('_');
      final roomNo = parts[0].trim();
      final block = parts.length > 1 ? parts[1].trim() : '';
      return block.isNotEmpty ? '$roomNo ($block)' : roomNo;
    }
    return roomRaw;
  }

  String _formatClassType(String? ltp, String subject) {
    final lowerSub = subject.toLowerCase();
    final lowerLtp = (ltp ?? '').toLowerCase();
    if (lowerLtp.contains('lab') || lowerLtp.contains('practical') || lowerLtp == 'p' || lowerSub.contains('lab')) {
      return 'Practical / Lab';
    }
    if (lowerLtp.contains('tutorial') || lowerLtp == 't') {
      return 'Tutorial';
    }
    if (lowerLtp.contains('seminar')) {
      return 'Seminar';
    }
    if (lowerLtp.contains('project')) {
      return 'Project';
    }
    return 'Lecture';
  }

  Color _getStatusColor(bool isCancelled) {
    if (isCancelled) return const Color(0xFFDC2626);
    final s = widget.status.toLowerCase();
    if (s.contains('ongoing') || s.contains('now')) return const Color(0xFF16A34A);
    if (s.contains('up next') || s.contains('start') || s.contains('upcoming')) return const Color(0xFF003870);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classEvent;
    final subject = c['subject'] as String? ?? 'Unknown Subject';
    final rawRoom = c['room'] as String?;
    final faculty = (c['faculty'] as String?)?.trim();
    final ltp = c['ltp'] as String?;
    final startTime = c['start_time'] as String? ?? '';
    final endTime = c['end_time'] as String? ?? '';
    final isCancelled = c['isCancelled'] == true || widget.status.toLowerCase() == 'cancelled';

    final location = _formatLocation(rawRoom);
    final duration = _calculateDuration(startTime, endTime);
    final classType = _formatClassType(ltp, subject);

    final dayStr = c['day']?.toString() ?? '';
    final formattedDay = dayStr.isNotEmpty
        ? '${dayStr[0].toUpperCase()}${dayStr.substring(1).toLowerCase()}'
        : 'Scheduled Class';
    final dateDisplay = widget.dateStr ?? formattedDay;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title and status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLASS DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subject,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getStatusColor(isCancelled).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCancelled ? 'Cancelled' : widget.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(isCancelled),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              // Date
              _buildRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: dateDisplay,
              ),

              // Time & Duration
              _buildRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: startTime.isNotEmpty && endTime.isNotEmpty
                    ? '${TimeUtils.format12Hour(startTime)} – ${TimeUtils.format12Hour(endTime)}'
                    : 'Time not specified',
                extra: duration,
              ),

              // Location / Room
              _buildRow(
                icon: Icons.place_outlined,
                label: 'Location',
                value: location,
              ),

              // Faculty
              _buildRow(
                icon: Icons.person_outline_rounded,
                label: 'Faculty',
                value: faculty != null && faculty.isNotEmpty ? faculty : 'Faculty not assigned',
              ),

              // Class Type
              _buildRow(
                icon: Icons.school_outlined,
                label: 'Class Type',
                value: classType,
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // ATTENDANCE SECTION (Students only)
              if (StorageService.isStudentMode()) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ATTENDANCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Color(0xFF003870),
                      ),
                    ),
                    if (_lastSynced != null)
                      Text(
                        'Synced ${_formatTimeAgo(_lastSynced!)}',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildAttendanceCard(),
                const SizedBox(height: 16),
              ],

              // Action buttons
              if (StorageService.isStudentMode())
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AttendanceScreen()),
                      );
                    },
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('View Full Attendance', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003870),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
    String? extra,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF003870)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (extra != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                extra,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    if (_isLoadingAttendance) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003870)),
          ),
        ),
      );
    }

    if (_attendance == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Attendance data unavailable',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final att = _attendance!;
    final pct = att.attendancePercentage;
    final isSafe = pct >= 75.0;
    final isCondonation = pct >= 65.0 && pct < 75.0;

    final Color statusColor = isSafe
        ? const Color(0xFF16A34A)
        : isCondonation
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    final Color statusBg = isSafe
        ? const Color(0xFFDCFCE7)
        : isCondonation
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);

    final String statusLabel = isSafe
        ? 'Safe / Eligible'
        : isCondonation
            ? 'Condonation Zone'
            : 'Attendance Low';

    final attended = att.presentCount ?? 0;
    final conducted = att.totalCount ?? 0;
    final needed = att.classesNeededFor75 ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Attendance',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (pct / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attended: $attended  ·  Conducted: $conducted',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
              ),
              if (!isSafe && needed > 0)
                Text(
                  'Need $needed class${needed > 1 ? 'es' : ''}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                )
              else if (isSafe)
                const Text(
                  'Eligible for exams',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
