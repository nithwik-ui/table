import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme_controller.dart';
import '../../core/utils.dart';
import '../../core/storage.dart';
import '../../core/sraap/sraap_academic_service.dart';
import '../../core/sraap/sraap_session_manager.dart';
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
  bool _isShowingFresh = false;
  SraapAcademicData? _data;
  String? _errorMessage;
  bool _isOffline = false;

  // Placement Attendance State
  double? _placementAttendance;
  bool _isLoadingPlacement = true;
  bool _placementError = false;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _placementAttendance = SraapAcademicService.instance.getCachedPlacementAttendance();
    _isLoadingPlacement = _placementAttendance == null;
    _loadAttendance();
    _loadPlacementAttendance();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadPlacementAttendance({bool forceRefresh = false}) async {
    if (!StorageService.isSraapConnected()) {
      if (mounted) {
        setState(() {
          _isLoadingPlacement = false;
        });
      }
      return;
    }

    if (mounted && _placementAttendance == null) {
      setState(() {
        _isLoadingPlacement = true;
        _placementError = false;
      });
    }

    try {
      final fresh = await SraapAcademicService.instance.fetchPlacementAttendance();
      if (mounted) {
        setState(() {
          if (fresh != null) {
            _placementAttendance = fresh;
            _placementError = false;
          }
          _isLoadingPlacement = false;
        });
      }
    } catch (e) {
      debugPrint('[SRAAP] Placement attendance fetch error: $e');
      if (mounted) {
        setState(() {
          if (_placementAttendance == null) {
            _placementError = true;
          }
          _isLoadingPlacement = false;
        });
      }
    }
  }

  Future<void> _loadAttendance({bool forceRefresh = false}) async {
    _loadPlacementAttendance(forceRefresh: forceRefresh);

    // 1. Immediately render cached data
    final cached = SraapAcademicService.instance.getCachedAcademicData();
    if (cached != null && _data == null) {
      _data = cached;
      _isLoading = false;
      _isShowingFresh = false;
    }

    if (!mounted) return;
    setState(() {
      _isRefreshing = _data != null;
      _isLoading = _data == null;
      _errorMessage = null;
    });

    // 2. Immediately fetch live data from the main SRAAP page
    if (StorageService.isSraapConnected()) {
      try {
        final fresh = await SraapAcademicService.instance.fetchFreshDataSilently();
        if (mounted && fresh != null) {
          setState(() {
            _data = fresh;
            _isLoading = false;
            _isRefreshing = false;
            _isOffline = false;
            _isShowingFresh = true;
          });
          return;
        }
      } catch (e) {
        debugPrint('[SRAAP] Live attendance fetch error: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      if (_data == null) {
        final c = SraapAcademicService.instance.getCachedAcademicData();
        if (c != null) {
          _data = c;
          _isOffline = true;
        } else {
          _errorMessage = "Couldn't load attendance. Check your connection and try again.";
        }
      } else {
        _isOffline = true;
      }
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  String _formatLastUpdated(DateTime? dateTime) {
    if (dateTime == null) return 'Never updated';
    final now = TimeUtils.getKolkataTime();
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
      backgroundColor: AppConstants.surface,
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
                      color: AppConstants.outline,
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
                        color: AppConstants.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.badge_outlined, color: AppConstants.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SRAAP Portal Status',
                          style: AppConstants.getHeadline().copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roll != null && roll.isNotEmpty ? 'Roll No: $roll' : 'Student Academic Account',
                          style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppConstants.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConstants.outline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Portal Connection', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppConstants.successContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Connected',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.successText),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 20, color: AppConstants.outline),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Mentor', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                          Text(mentorName, style: AppConstants.getBodyMedium().copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (mentorDept != null && mentorDept.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Contact Info', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                            Text(mentorDept, style: AppConstants.getBodyMedium().copyWith(fontSize: 12)),
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
                      backgroundColor: AppConstants.primary,
                      foregroundColor: AppConstants.onPrimary,
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
    if (!StorageService.isStudentMode()) {
      return Scaffold(
        backgroundColor: AppConstants.background,
        appBar: AppBar(title: const Text('Attendance')),
        body: const Center(child: Text('Attendance is only available for students.')),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: AppConstants.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppConstants.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'sru',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppConstants.primary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Academic • Attendance',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.badge_outlined, color: AppConstants.textPrimary),
            tooltip: 'Student Info',
            onPressed: _showStudentPortalInfo,
          ),
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary),
                  )
                : Icon(Icons.history_rounded, color: AppConstants.textPrimary),
            tooltip: 'Refresh attendance',
            onPressed: _isRefreshing ? null : () => _loadAttendance(forceRefresh: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppConstants.primary,
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

    if (_data == null && !StorageService.isSraapConnected()) {
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your subject-wise attendance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppConstants.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (_isOffline)
          _buildOfflineBanner(),
        _buildOverallAttendanceCard(overall, data.lastSynced),
        const SizedBox(height: 14),
        _buildThresholdStatusCards(),
        const SizedBox(height: 22),
        _buildSubjectSectionHeader(subjects.length),
        const SizedBox(height: 12),
        ...subjects.map((sub) => _buildSubjectCard(sub)),
        if (data.recentDailyAttendance.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildRecentDailyAttendanceSection(data.recentDailyAttendance),
        ],
        const SizedBox(height: 20),
        _buildPlacementSectionHeader(),
        const SizedBox(height: 12),
        _buildPlacementAttendanceCard(),
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
        color: AppConstants.warningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: AppConstants.warningText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cached • Showing saved attendance',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.warningText),
            ),
          ),
          TextButton(
            onPressed: () => _loadAttendance(forceRefresh: true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.warningText)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallAttendanceCard(double overall, DateTime lastSynced) {
    final isSafe = overall >= 75.0;
    final isCondonation = overall >= 65.0 && overall < 75.0;

    final Color statusColor = isSafe
        ? AppConstants.successText
        : isCondonation
            ? AppConstants.warningText
            : AppConstants.errorText;

    final Color badgeBg = isSafe
        ? AppConstants.successContainer
        : isCondonation
            ? AppConstants.warningContainer
            : AppConstants.errorContainer;

    final String statusText = isSafe
        ? 'Safe • Eligible'
        : isCondonation
            ? 'Condonation Zone'
            : 'Low Attendance';

    final IconData statusIcon = isSafe
        ? Icons.check_circle_rounded
        : Icons.warning_rounded;

    final isStale = _isOffline ||
        SraapSessionManager.instance.isSessionExpired ||
        !_isShowingFresh ||
        DateTime.now().difference(lastSynced).inMinutes > 30;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppConstants.outline),
        boxShadow: AppConstants.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Overall Attendance',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isStale ? AppConstants.warningContainer : AppConstants.successContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isStale ? 'Cached' : 'Fresh',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isStale ? AppConstants.warningText : AppConstants.successText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
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
                          Text(
                            '/ 100%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                          color: AppConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.info_outline_rounded, size: 13, color: AppConstants.textMuted),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Across all subjects',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (overall / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppConstants.outline,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: AppConstants.textMuted),
              const SizedBox(width: 5),
              Text(
                _formatLastUpdated(lastSynced),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppConstants.textSecondary,
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
                circleColor: AppConstants.errorContainer,
                iconColor: AppConstants.errorText,
                icon: Icons.error_outline_rounded,
                rangeText: 'Below 65%',
                titleText: 'Detention Risk',
                subtitleText: 'May not be allowed to appear for exams.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGuidanceCard(
                circleColor: AppConstants.warningContainer,
                iconColor: AppConstants.warningText,
                icon: Icons.warning_amber_rounded,
                rangeText: '65% – 74.99%',
                titleText: 'Condonation Zone',
                subtitleText: 'May be eligible with condonation fee.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGuidanceCard(
                circleColor: AppConstants.successContainer,
                iconColor: AppConstants.successText,
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
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.outline),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItem(AppConstants.successText, '75%+ Safe'),
            const SizedBox(width: 12),
            Container(width: 1, height: 12, color: AppConstants.outline),
            const SizedBox(width: 12),
            _buildLegendItem(AppConstants.warningText, '65–74% Condonation'),
            const SizedBox(width: 12),
            Container(width: 1, height: 12, color: AppConstants.outline),
            const SizedBox(width: 12),
            _buildLegendItem(AppConstants.errorText, '<65% Warning'),
          ],
        ),
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
            color: AppConstants.textSecondary,
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
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.outline),
        boxShadow: AppConstants.shadowLevel1,
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
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
            style: TextStyle(
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: AppConstants.textSecondary,
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
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppConstants.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.menu_book_rounded, size: 18, color: AppConstants.primary),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Subject Attendance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count Courses Enrolled',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppConstants.textSecondary,
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
        ? AppConstants.successText
        : isCondonation
            ? AppConstants.warningText
            : AppConstants.errorText;

    final Color badgeBg = isSafe
        ? AppConstants.successContainer
        : isCondonation
            ? AppConstants.warningContainer
            : AppConstants.errorContainer;

    final String statusText = isSafe
        ? 'Safe'
        : isCondonation
            ? 'Condonation Zone'
            : 'Detention Risk';

    final IconData iconData = _getSubjectIcon(sub.subjectName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? AppConstants.error.withValues(alpha: 0.5) : AppConstants.outline,
          width: isWarning ? 1.3 : 1.0,
        ),
        boxShadow: AppConstants.shadowLevel1,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.subjectName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (sub.totalCount != null && sub.presentCount != null)
                            Text(
                              '${sub.presentCount} attended · ${sub.totalCount} conducted',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppConstants.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    Icon(Icons.chevron_right_rounded, size: 20, color: AppConstants.textMuted),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (pct / 100.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppConstants.outline,
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
        color: AppConstants.infoContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_rounded, size: 20, color: AppConstants.infoText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Maintain at least 75% attendance in each subject to be eligible to appear for university exams.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppConstants.infoText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppConstants.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.school_rounded, size: 16, color: AppConstants.primary),
        ),
        const SizedBox(width: 8),
        Text(
          'Placements Attendance',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPlacementAttendanceCard() {
    if (_isLoadingPlacement && _placementAttendance == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppConstants.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.outline),
          boxShadow: AppConstants.shadowLevel1,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppConstants.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Placements Attendance',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Loading attendance...',
                    style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_placementError && _placementAttendance == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppConstants.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.outline),
          boxShadow: AppConstants.shadowLevel1,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppConstants.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.error_outline_rounded, size: 22, color: AppConstants.errorText),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Placements Attendance',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unable to update',
                    style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 20, color: AppConstants.primary),
              tooltip: 'Retry',
              onPressed: () => _loadPlacementAttendance(forceRefresh: true),
            ),
          ],
        ),
      );
    }

    final pct = _placementAttendance ?? 0.0;
    final isSafe = pct >= 75.0;
    final isCondonation = pct >= 65.0 && pct < 75.0;

    final Color statusColor = isSafe
        ? AppConstants.successText
        : isCondonation
            ? AppConstants.warningText
            : AppConstants.errorText;

    final Color iconBg = isSafe
        ? AppConstants.successContainer
        : isCondonation
            ? AppConstants.warningContainer
            : AppConstants.errorContainer;

    final formattedPct = pct.truncateToDouble() == pct ? '${pct.toInt()}%' : '${pct.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.outline),
        boxShadow: AppConstants.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school_rounded, size: 22, color: statusColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Placements Attendance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Campus Recruitment & Training',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formattedPct,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (pct / 100.0).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppConstants.outline,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
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
            color: AppConstants.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.outline),
          ),
          child: Center(
            child: CircularProgressIndicator(color: AppConstants.primary),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: AppConstants.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppConstants.outline),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (i) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppConstants.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppConstants.outline),
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
                color: AppConstants.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.school_rounded, color: AppConstants.primary, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Connect SRAAP for Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with your SR University Academic Portal to view your real attendance and classes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppConstants.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
                ).then((_) => _loadAttendance(forceRefresh: true));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: AppConstants.onPrimary,
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
            Icon(Icons.event_busy_rounded, size: 56, color: AppConstants.textMuted),
            const SizedBox(height: 16),
            Text(
              'No attendance data available',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your academic portal has not published attendance records for this term yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppConstants.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadAttendance(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: AppConstants.onPrimary,
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
            Icon(Icons.cloud_off_rounded, size: 56, color: AppConstants.errorText),
            const SizedBox(height: 16),
            Text(
              "Couldn't load attendance",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppConstants.textSecondary),
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
                    backgroundColor: AppConstants.primary,
                    foregroundColor: AppConstants.onPrimary,
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
        ? AppConstants.successText
        : isCondonation
            ? AppConstants.warningText
            : AppConstants.errorText;

    final Color badgeBg = isSafe
        ? AppConstants.successContainer
        : isCondonation
            ? AppConstants.warningContainer
            : AppConstants.errorContainer;

    final int? needed = sub.classesNeededFor75;
    final int? canMiss = sub.classesCanMissWhileSafe;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.surface,
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
                    color: AppConstants.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (sub.subjectCode != null && sub.subjectCode!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: AppConstants.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sub.subjectCode!,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.primary),
                  ),
                ),
              Text(
                sub.subjectName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppConstants.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppConstants.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attendance', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
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
                        color: AppConstants.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppConstants.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Classes Attended', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${sub.presentCount ?? 0} / ${sub.totalCount ?? 0}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                        style: TextStyle(fontSize: 13, height: 1.3, color: statusColor),
                      )
                    else if (!isSafe && needed != null)
                      Text(
                        'You need to attend the next $needed class${needed > 1 ? 'es' : ''} consecutively to reach 75% safe attendance.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (sub.detailHref != null && sub.detailHref!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showPortalDetailLogSheet(
                        title: sub.subjectName,
                        subtitle: 'Subject-wise Attendance Log',
                        path: sub.detailHref!,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.primary,
                      side: BorderSide(color: AppConstants.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    label: const Text(
                      'View Date-Wise Attendance Log',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primary,
                    foregroundColor: AppConstants.onPrimary,
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

  Widget _buildRecentDailyAttendanceSection(
    List<SraapDailyAttendance> dailyList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Last Week Attendance',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppConstants.textPrimary,
              ),
            ),
            Text(
              'Tap date for period log',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppConstants.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppConstants.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.outline),
            boxShadow: AppConstants.shadowLevel1,
          ),
          child: Column(
            children: List.generate(dailyList.length, (i) {
              final d = dailyList[i];
              final isFull = d.held > 0 && d.attended == d.held;
              final isZero = d.attended == 0;
              final color = isFull
                  ? AppConstants.successText
                  : (isZero ? AppConstants.errorText : AppConstants.warningText);
              final bg = isFull
                  ? AppConstants.successContainer
                  : (isZero
                        ? AppConstants.errorContainer
                        : AppConstants.warningContainer);

              return Column(
                children: [
                  if (i > 0) Divider(height: 1, color: AppConstants.outline),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: d.detailHref != null && d.detailHref!.isNotEmpty
                        ? () => _showPortalDetailLogSheet(
                              title: 'Attendance on ${d.date}',
                              subtitle:
                                  'Attended ${d.attended} of ${d.held} classes',
                              path: d.detailHref!,
                            )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  size: 15,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.date,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppConstants.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Held: ${d.held} • Attended: ${d.attended}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppConstants.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${d.attended}/${d.held}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                              if (d.detailHref != null &&
                                  d.detailHref!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: AppConstants.textMuted,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  void _showPortalDetailLogSheet({
    required String title,
    required String subtitle,
    required String path,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return FutureBuilder<List<Map<String, String>>>(
              future: SraapAcademicService.instance.fetchPortalDetailTable(path),
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;
                final rows = snapshot.data ?? const [];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppConstants.outline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: AppConstants.getHeadline().copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppConstants.getLabelSmall(
                          color: AppConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: loading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: AppConstants.primary,
                                ),
                              )
                            : rows.isEmpty
                                ? Center(
                                    child: Text(
                                      'No detailed records returned from SRAAP.',
                                      style: AppConstants.getBodyMedium(
                                        color: AppConstants.textSecondary,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    itemCount: rows.length,
                                    itemBuilder: (_, idx) {
                                      final row = rows[idx];
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppConstants.background,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: AppConstants.outline,
                                          ),
                                        ),
                                        child: Wrap(
                                          spacing: 12,
                                          runSpacing: 6,
                                          children: row.entries
                                              .map(
                                                (e) => Text(
                                                  '${e.key}: ${e.value}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppConstants
                                                        .textPrimary,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
