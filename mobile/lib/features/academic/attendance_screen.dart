import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/sraap/sraap_academic_service.dart';
import '../../core/sraap/models/sraap_academic_data.dart';
import 'academic_login_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  SraapAcademicData? _data;
  String? _errorMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (forceRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = _data == null;
      }
      _errorMessage = null;
    });

    try {
      final data = await SraapAcademicService.instance.getAcademicData(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
        _isRefreshing = false;
        _isOffline = false;
      });
    } catch (e) {
      if (!mounted) return;
      // If network failed, load from cache
      final cached = await SraapAcademicService.instance.getAcademicData(forceRefresh: false);
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        if (_data == null && cached != null) {
          _data = cached;
          _isOffline = true;
        } else if (_data == null) {
          _errorMessage = "Couldn't load attendance. Check your connection and try again.";
        } else {
          _isOffline = true;
        }
      });
    }
  }

  String _formatLastUpdated(DateTime? dateTime) {
    if (dateTime == null) return 'Never updated';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) {
      return 'Updated just now';
    } else if (diff.inMinutes < 60) {
      return 'Updated ${diff.inMinutes} min ago';
    } else if (diff.inHours < 24 && dateTime.day == now.day) {
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
      return 'Last updated today at $hour:$minute $ampm';
    } else {
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
      return 'Updated on ${dateTime.day}/${dateTime.month} at $hour:$minute $ampm';
    }
  }

  IconData _getSubjectIcon(String subjectName) {
    final lower = subjectName.toLowerCase();
    if (lower.contains('software') || lower.contains('system') || lower.contains('web') || lower.contains('app') || lower.contains('cloud') || lower.contains('devops')) {
      return Icons.laptop_chromebook_rounded;
    } else if (lower.contains('algorithm') || lower.contains('data struct') || lower.contains('program') || lower.contains('java') || lower.contains('python') || lower.contains('c++')) {
      return Icons.code_rounded;
    } else if (lower.contains('ai') || lower.contains('intelligence') || lower.contains('learning') || lower.contains('neural') || lower.contains('nlp')) {
      return Icons.psychology_rounded;
    } else if (lower.contains('skill') || lower.contains('interpersonal') || lower.contains('critical') || lower.contains('english') || lower.contains('communicat') || lower.contains('human')) {
      return Icons.group_rounded;
    } else if (lower.contains('stat') || lower.contains('math') || lower.contains('discrete') || lower.contains('calculus') || lower.contains('probability') || lower.contains('linear')) {
      return Icons.analytics_outlined;
    }
    return Icons.menu_book_rounded;
  }

  void _showStudentPortalInfo() {
    final roll = StorageService.getRollNumber();
    final data = _data;
    final mentorName = data?.mentor?.name ?? 'Assigned Faculty';
    final mentorDept = data?.mentor?.department;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5E3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.badge_outlined, color: Color(0xFF003870), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SRAAP Portal Status',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roll != null && roll.isNotEmpty ? 'Roll No: $roll' : 'Student Academic Account',
                          style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Portal Connection', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mentor', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          Text(mentorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        ],
                      ),
                      if (mentorDept != null && mentorDept.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Contact Info', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text(mentorDept, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003870),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only students should see this screen. Safety check.
    if (!StorageService.isStudentMode()) {
      return Scaffold(
        backgroundColor: AppConstants.background,
        appBar: AppBar(title: const Text('Attendance')),
        body: const Center(child: Text('Attendance is only available for students.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'sru',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF003870),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Academic • Attendance',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_outlined, color: Color(0xFF0F172A)),
            tooltip: 'Student Info',
            onPressed: _showStudentPortalInfo,
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003870)),
                  )
                : const Icon(Icons.history_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Refresh attendance',
            onPressed: _isRefreshing ? null : () => _loadAttendance(forceRefresh: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF003870),
          onRefresh: () => _loadAttendance(forceRefresh: true),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeletonLoader();
    }

    if (_errorMessage != null && _data == null) {
      return _buildErrorState();
    }

    if (!StorageService.isSraapConnected()) {
      return _buildConnectState();
    }

    if (_data == null || (_data!.subjects.isEmpty && _data!.overallAttendance == null)) {
      return _buildEmptyState();
    }

    final data = _data!;
    final overall = data.overallAttendance ?? 0.0;
    final subjects = data.subjects;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Screen Header: Attendance / "Your subject-wise attendance"
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your subject-wise attendance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
        ),
        if (_isOffline) _buildOfflineBanner(),
        _buildOverallAttendanceCard(overall, data.lastSynced),
        const SizedBox(height: 14),
        _buildThresholdStatusCards(),
        const SizedBox(height: 22),
        _buildSubjectSectionHeader(subjects.length),
        const SizedBox(height: 12),
        ...subjects.map((sub) => _buildSubjectCard(sub)),
        const SizedBox(height: 16),
        _buildFooterInfoCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFFEA580C)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Offline • Showing saved attendance',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9A3412)),
            ),
          ),
          TextButton(
            onPressed: () => _loadAttendance(forceRefresh: true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallAttendanceCard(double overall, DateTime lastSynced) {
    final isSafe = overall >= 75.0;
    final isCondonation = overall >= 65.0 && overall < 75.0;

    final Color statusColor = isSafe
        ? const Color(0xFF16A34A)
        : isCondonation
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    final Color badgeBg = isSafe
        ? const Color(0xFFDCFCE7)
        : isCondonation
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);

    final String statusText = isSafe
        ? 'Safe • Eligible'
        : isCondonation
            ? 'Condonation Zone'
            : 'Low Attendance';

    final IconData statusIcon = isSafe
        ? Icons.check_circle_rounded
        : Icons.warning_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Title + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bar_chart_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Attendance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${overall.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/ 100%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Badge Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Min 75% required',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.info_outline_rounded, size: 13, color: Colors.blueGrey.shade400),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Subtext Row: Min 75% required
          const Text(
            'Across all subjects',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          // Horizontal Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (overall / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          // Timestamp
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: Colors.blueGrey.shade400),
              const SizedBox(width: 5),
              Text(
                _formatLastUpdated(lastSynced),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdStatusCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGuidanceCard(
                circleColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                icon: Icons.error_outline_rounded,
                rangeText: 'Below 65%',
                titleText: 'Detention Risk',
                subtitleText: 'May not be allowed to appear for exams.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGuidanceCard(
                circleColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                icon: Icons.warning_amber_rounded,
                rangeText: '65% – 74.99%',
                titleText: 'Condonation Zone',
                subtitleText: 'May be eligible with condonation fee.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGuidanceCard(
                circleColor: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                icon: Icons.check_circle_outline_rounded,
                rangeText: '75% and above',
                titleText: 'Safe / Eligible',
                subtitleText: 'Eligible to appear for university exams.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCompactStatusLegend(),
      ],
    );
  }

  Widget _buildCompactStatusLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(const Color(0xFF16A34A), '75%+ Safe'),
          Container(width: 1, height: 12, color: const Color(0xFFE2E8F0)),
          _buildLegendItem(const Color(0xFFD97706), '65–74.99% Condonation'),
          Container(width: 1, height: 12, color: const Color(0xFFE2E8F0)),
          _buildLegendItem(const Color(0xFFDC2626), '<65% Warning'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildGuidanceCard({
    required Color circleColor,
    required Color iconColor,
    required IconData icon,
    required String rangeText,
    required String titleText,
    required String subtitleText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            rangeText,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitleText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSectionHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFD5E3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF003870)),
            ),
            const SizedBox(width: 8),
            const Text(
              'Subject Attendance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Text(
          '$count Courses Enrolled',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(SraapSubjectAttendance sub) {
    final pct = sub.attendancePercentage;
    final isSafe = pct >= 75.0;
    final isCondonation = pct >= 65.0 && pct < 75.0;
    final isWarning = pct < 65.0;

    final Color statusColor = isSafe
        ? const Color(0xFF16A34A)
        : isCondonation
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    final Color badgeBg = isSafe
        ? const Color(0xFFDCFCE7)
        : isCondonation
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);

    final String statusText = isSafe
        ? 'Safe'
        : isCondonation
            ? 'Condonation Zone'
            : 'Detention Risk';

    final IconData iconData = _getSubjectIcon(sub.subjectName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFFBFB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: isWarning ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSubjectDetails(sub),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Category Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconData, size: 20, color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    // Course Name and classes count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.subjectName.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (sub.totalCount != null && sub.presentCount != null)
                            Text(
                              '${sub.presentCount} attended · ${sub.totalCount} conducted',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Percentage & Status Badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSafe ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                size: 11,
                                color: statusColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress Bar (Clamped safely between 0.0 and 1.0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (pct / 100.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0DCFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_rounded, size: 20, color: Color(0xFF003870)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Maintain at least 75% attendance in each subject to be eligible to appear for university exams.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF003870),
                height: 1.35,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF003870)),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF003870)),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (i) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFD5E3FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.school_rounded, color: Color(0xFF003870), size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connect SRAAP for Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in with your SR University Academic Portal to view your real attendance and classes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
                ).then((_) => _loadAttendance(forceRefresh: true));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003870),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Connect SRAAP', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded, size: 56, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text(
              'No attendance data available',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your academic portal has not published attendance records for this term yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadAttendance(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003870),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFFDC2626)),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load attendance",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
                    ).then((_) => _loadAttendance(forceRefresh: true));
                  },
                  child: const Text('Reconnect SRAAP'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _loadAttendance(forceRefresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003870),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openSubjectDetails(SraapSubjectAttendance sub) {
    final pct = sub.attendancePercentage;
    final isSafe = pct >= 75.0;
    final isCondonation = pct >= 65.0 && pct < 75.0;

    final Color statusColor = isSafe
        ? const Color(0xFF16A34A)
        : isCondonation
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    final Color badgeBg = isSafe
        ? const Color(0xFFDCFCE7)
        : isCondonation
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);

    final int? needed = sub.classesNeededFor75;
    final int? canMiss = sub.classesCanMissWhileSafe;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Subject Code + Name
              if (sub.subjectCode != null && sub.subjectCode!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sub.subjectCode!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                ),
              Text(
                sub.subjectName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              // Key Metrics Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attendance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Classes Attended', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            '${sub.presentCount ?? 0} / ${sub.totalCount ?? 0}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Status Pill & Advice Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isSafe ? Icons.check_circle_rounded : Icons.warning_rounded, color: statusColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          sub.statusLabel,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isSafe && canMiss != null)
                      Text(
                        canMiss > 0
                            ? 'You can miss the next $canMiss class${canMiss > 1 ? 'es' : ''} and still maintain 75% attendance.'
                            : 'Attendance is above 75%. Keep attending classes to remain safe.',
                        style: TextStyle(fontSize: 13, height: 1.3, color: Colors.green.shade900),
                      )
                    else if (!isSafe && needed != null)
                      Text(
                        'You need to attend the next $needed class${needed > 1 ? 'es' : ''} consecutively to reach 75% safe attendance.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: isCondonation ? Colors.amber.shade900 : Colors.red.shade900,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003870),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
