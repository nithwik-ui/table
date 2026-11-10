import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme_controller.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/auth/secure_session_store.dart';
import '../../core/sraap/sraap_auth_manager.dart';
import '../../core/sraap/sraap_session_manager.dart';
import '../../core/sraap/sraap_academic_service.dart';
import '../../core/sraap/models/sraap_academic_data.dart';
import 'academic_login_screen.dart';
import 'attendance_screen.dart';
import 'internal_marks_screen.dart';

class AcademicDashboard extends StatefulWidget {
  const AcademicDashboard({super.key});

  @override
  State<AcademicDashboard> createState() => _AcademicDashboardState();
}

class _AcademicDashboardState extends State<AcademicDashboard> {
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isSessionExpired = false;
  bool _isShowingFresh = false;
  SraapAcademicData? _data;
  SraapInternalMarksData? _internalMarks;
  double? _placementAttendance;
  String? _error;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _isSessionExpired = SraapSessionManager.instance.isSessionExpired;
    _placementAttendance =
        SraapAcademicService.instance.getCachedPlacementAttendance();
    _internalMarks = SraapAcademicService.instance.getCachedInternalMarks();
    _loadData();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // 1. Immediately render cached data if available (never erase on session expiry)
    final cached = SraapAcademicService.instance.getCachedAcademicData();
    if (cached != null && _data == null) {
      _data = cached;
      _isLoading = false;
      _isShowingFresh = false;
    }
    final cachedMarks = SraapAcademicService.instance.getCachedInternalMarks();
    if (cachedMarks != null && _internalMarks == null) {
      _internalMarks = cachedMarks;
    }

    if (mounted) {
      setState(() {
        if (_data == null) _isLoading = true;
        _isSyncing = true;
        _error = null;
        _isSessionExpired = SraapSessionManager.instance.isSessionExpired;
      });
    }

    // 2. Fetch live data from SRAAP
    if (StorageService.isSraapConnected()) {
      // Non-blocking placement attendance refresh
      SraapAcademicService.instance.fetchPlacementAttendance().then((p) {
        if (mounted && p != null) {
          setState(() => _placementAttendance = p);
        }
      }).catchError((_) {});

      // Non-blocking internal marks refresh
      SraapAcademicService.instance
          .fetchInternalMarks(forceRefresh: forceRefresh)
          .then((marks) {
        if (mounted && marks != null) {
          setState(() => _internalMarks = marks);
        }
      }).catchError((_) {});

      try {
        final fresh = await SraapAcademicService.instance.getAcademicData(
          forceRefresh: forceRefresh,
        );
        if (mounted && fresh != null) {
          setState(() {
            _data = fresh;
            _isLoading = false;
            _isSyncing = false;
            _isSessionExpired = false;
            _isShowingFresh = true;
          });
          if (forceRefresh) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Academic data updated from SRAAP'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      } on SraapSessionExpiredException {
        debugPrint('[SRAAP] Session expired on sraap.in');
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _isLoading = false;
            _isSessionExpired = true;
            _isShowingFresh = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('[SRAAP] Live dashboard fetch error: $e');
        if (mounted && forceRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not reach SRAAP. Showing saved data.'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        if (_data == null) {
          final c = SraapAcademicService.instance.getCachedAcademicData();
          if (c != null) {
            _data = c;
          } else {
            _error = 'Not connected to SRAAP.';
          }
        }
        _isLoading = false;
        _isSyncing = false;
      });
    }
  }

  String _formatTimeAgo(DateTime time) {
    final now = TimeUtils.getKolkataTime();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    if (diff.inHours < 24 && time.day == now.day) {
      final hour = time.hour > 12
          ? time.hour - 12
          : (time.hour == 0 ? 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour >= 12 ? 'PM' : 'AM';
      return 'Last updated today at $hour:$minute $ampm';
    }
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return 'Last updated on ${time.day}/${time.month} at $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: AppConstants.primary,
          child: _isLoading && _data == null
              ? Center(
                  child: CircularProgressIndicator(color: AppConstants.primary),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 48,
              color: AppConstants.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Not connected to SRAAP.',
              style: AppConstants.getBodyLarge(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: AppConstants.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusButton,
                  ),
                ),
              ),
              icon: const Icon(Icons.link),
              label: const Text(
                'Connect SRAAP',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const AcademicLoginScreen(),
                      ),
                    )
                    .then((_) => _loadData());
              },
            ),
          ],
        ),
      );
    }

    final data = _data!;
    final attendance = data.overallAttendance ?? 0.0;
    final cgpa = data.cgpa ?? '0.0';
    final mentorName = data.mentor?.name ?? 'Not Assigned';
    final mentorDept = data.mentor?.department ?? 'Department';

    final isSafe = attendance >= 75.0;
    final isCondonation = attendance >= 65.0 && attendance < 75.0;
    final statusColor = isSafe
        ? AppConstants.successText
        : (isCondonation ? AppConstants.warningText : AppConstants.errorText);
    final badgeBg = isSafe
        ? AppConstants.successContainer
        : (isCondonation
              ? AppConstants.warningContainer
              : AppConstants.errorContainer);
    final statusText = isSafe
        ? 'Safe / Eligible'
        : isCondonation
            ? 'Condonation Zone'
            : 'Low Attendance';

    // Fresh vs Cached / Stale indicator (Section 16)
    final isStale = _isSessionExpired ||
        !_isShowingFresh ||
        DateTime.now().difference(data.lastSynced).inMinutes > 30;
    final freshnessLabel = isStale ? 'Cached / Stale' : 'Fresh';
    final freshnessColor =
        isStale ? AppConstants.warningText : AppConstants.successText;
    final freshnessBg =
        isStale ? AppConstants.warningContainer : AppConstants.successContainer;

    final marksCourses = _internalMarks?.courses ?? const [];

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingContainer,
        vertical: 14,
      ),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Academic Space',
                        style: AppConstants.getDisplay(
                          color: AppConstants.primary,
                        ).copyWith(fontSize: 22),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: freshnessBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          freshnessLabel,
                          style: AppConstants.getMonoLabel(
                            color: freshnessColor,
                          ).copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      'SRAAP',
                      if (data.yearSem != null && data.yearSem!.isNotEmpty)
                        'Sem ${data.yearSem}',
                      _formatTimeAgo(data.lastSynced),
                    ].join(' • '),
                    style: AppConstants.getBodyMedium(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: _isSyncing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.primary,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: AppConstants.primary,
                    ),
              onPressed: _isSyncing ? null : () => _loadData(forceRefresh: true),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Portal Announcements Marquee Banner (if any active schedule notice on SRAAP)
        if (data.announcements.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppConstants.secondaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppConstants.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.campaign_rounded,
                  color: AppConstants.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Today on SRAAP: ${data.announcements.join(' • ')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_isSessionExpired) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppConstants.warningContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
              border: Border.all(
                color: AppConstants.warning.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppConstants.warning,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SRAAP Session Expired',
                        style: AppConstants.getBodyMedium(
                          color: AppConstants.textPrimary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Showing saved data. Tap RENEW to enter CAPTCHA and refresh live attendance & marks.',
                        style: AppConstants.getBodyMedium(
                          color: AppConstants.textSecondary,
                        ).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primary,
                    foregroundColor: AppConstants.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _showQuickReconnectSheet,
                  child: const Text(
                    'RENEW',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 1. Featured Overall Attendance Card
        Container(
          decoration: BoxDecoration(
            color: AppConstants.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
            border: Border.all(color: AppConstants.outline),
            boxShadow: AppConstants.shadowLevel1,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
              onTap: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const AttendanceScreen(),
                      ),
                    )
                    .then((_) => _loadData());
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusButton,
                                ),
                              ),
                              child: Icon(
                                Icons.bar_chart_rounded,
                                color: statusColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Overall Attendance',
                                  style: AppConstants.getLabelSmall(
                                    color: AppConstants.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${attendance.toStringAsFixed(1)}%',
                                      style: AppConstants.getDisplay(
                                        color: statusColor,
                                      ).copyWith(fontSize: 26),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '/ 100%',
                                      style: AppConstants.getBodyMedium(
                                        color: AppConstants.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusCard,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSafe
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.warning_amber_rounded,
                                size: 13,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: AppConstants.getLabelSmall(
                                  color: statusColor,
                                ).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusCard,
                      ),
                      child: LinearProgressIndicator(
                        value: (attendance / 100).clamp(0.0, 1.0),
                        backgroundColor: AppConstants.outline.withValues(
                          alpha: 0.5,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 14,
                              color: AppConstants.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to view subject & daily attendance',
                              style: AppConstants.getBodyMedium(
                                color: AppConstants.primary,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppConstants.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Featured Results & Internal Marks (CIE / ETE) Card
        _buildFeaturedResultsCard(marksCourses),

        // 3. Placements Attendance Card
        if (_placementAttendance != null) ...[
          const SizedBox(height: 14),
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppConstants.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              size: 20,
                              color: AppConstants.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Placements Attendance',
                                  style: AppConstants.getHeadline().copyWith(
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Campus Recruitment & Training',
                                  style: AppConstants.getLabelSmall(
                                    color: AppConstants.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _placementAttendance!.truncateToDouble() ==
                              _placementAttendance!
                          ? '${_placementAttendance!.toInt()}%'
                          : '${_placementAttendance!.toStringAsFixed(1)}%',
                      style: AppConstants.getDisplay(
                        color: _placementAttendance! >= 75
                            ? AppConstants.successText
                            : (_placementAttendance! >= 65
                                  ? AppConstants.warningText
                                  : AppConstants.errorText),
                      ).copyWith(fontSize: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (_placementAttendance! / 100.0).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppConstants.outline.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _placementAttendance! >= 75
                          ? AppConstants.successText
                          : (_placementAttendance! >= 65
                                ? AppConstants.warningText
                                : AppConstants.errorText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        Text(
          'Academic Hub',
          style: AppConstants.getHeadline().copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),

        // Grid of Academic Options
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.32,
          children: [
            _buildOptionCard(
              icon: Icons.assessment_outlined,
              title: 'CIE / Mid Marks',
              value: marksCourses.isNotEmpty
                  ? 'Avg ${_internalMarks!.averageCie}'
                  : 'View Marks',
              subtitle: marksCourses.isNotEmpty
                  ? '${marksCourses.length} courses • Sem ${marksCourses.first.yearSem}'
                  : 'Sem-wise CIE & ETE',
              accentColor: AppConstants.primary,
              onTap: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const InternalMarksScreen(),
                      ),
                    )
                    .then((_) => _loadData());
              },
            ),
            _buildOptionCard(
              icon: Icons.fact_check_outlined,
              title: 'Attendance',
              value: '${attendance.toStringAsFixed(1)}%',
              subtitle: 'Subject & daily log',
              accentColor: statusColor,
              onTap: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const AttendanceScreen(),
                      ),
                    )
                    .then((_) => _loadData());
              },
            ),
            _buildOptionCard(
              icon: Icons.bar_chart_rounded,
              title: 'CGPA & Credits',
              value: cgpa,
              subtitle: data.backlogsCount != null
                  ? '${data.coursesCount ?? 0} Courses • ${data.backlogsCount} Backlogs'
                  : 'Out of 10.0',
              accentColor: AppConstants.info,
              onTap: () {
                final details = [
                  'Current Cumulative GPA: $cgpa / 10.0',
                  if (data.yearSem != null) 'Current Year-Sem: ${data.yearSem}',
                  if (data.batchNumber != null) 'Batch: ${data.batchNumber}',
                  if (data.coursesCount != null)
                    'Completed Courses: ${data.coursesCount}',
                  if (data.backlogsCount != null)
                    'Total Backlogs: ${data.backlogsCount}',
                ].join('\n');
                _showInfoModal('CGPA & Academic Standing', details);
              },
            ),
            _buildOptionCard(
              icon: Icons.person_outline_rounded,
              title: 'Faculty Mentor',
              value: mentorName.split(' ').first,
              subtitle: mentorDept,
              accentColor: AppConstants.success,
              onTap: () => _showMentorModal(mentorName, mentorDept),
            ),
            if (data.alphaCoins != null || data.sigmaCoins != null)
              _buildOptionCard(
                icon: Icons.stars_rounded,
                title: 'SSM Coins',
                value: _extractCoinSummary(data.alphaCoins),
                subtitle: data.sigmaCoins ?? 'Student Success Mgmt',
                accentColor: AppConstants.warningText,
                onTap: () {
                  final msg = [
                    if (data.alphaCoins != null) data.alphaCoins!,
                    if (data.sigmaCoins != null) data.sigmaCoins!,
                  ].join('\n');
                  _showInfoModal('Student Success Management (SSM)', msg);
                },
              )
            else if (_placementAttendance != null)
              _buildOptionCard(
                icon: Icons.work_outline_rounded,
                title: 'Placements',
                value: '${_placementAttendance!.toStringAsFixed(0)}%',
                subtitle: 'Placement attendance',
                accentColor: AppConstants.primary,
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const AttendanceScreen(),
                        ),
                      )
                      .then((_) => _loadData());
                },
              ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  String _extractCoinSummary(String? raw) {
    if (raw == null || raw.isEmpty) return 'SSM';
    final match = RegExp(r'(\d+\s*Coins)', caseSensitive: false).firstMatch(raw);
    if (match != null) return 'Alpha: ${match.group(1)}';
    return raw;
  }

  Widget _buildFeaturedResultsCard(List<SraapCourseMarks> courses) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(color: AppConstants.outline),
        boxShadow: AppConstants.shadowLevel1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const InternalMarksScreen(),
                  ),
                )
                .then((_) => _loadData());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppConstants.secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusButton,
                              ),
                            ),
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              color: AppConstants.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Results & Internal Marks',
                                  style: AppConstants.getHeadline().copyWith(
                                    fontSize: 15.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  courses.isNotEmpty
                                      ? 'Sem ${courses.first.yearSem} • ${courses.length} Courses CIE / ETE'
                                      : 'Sem Wise CIE / ETE Marks',
                                  style: AppConstants.getLabelSmall(
                                    color: AppConstants.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (courses.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppConstants.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Avg CIE: ${_internalMarks!.averageCie}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppConstants.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (courses.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: courses.take(4).map((c) {
                      final shortName = c.courseName.length > 18
                          ? '${c.courseName.substring(0, 18)}…'
                          : c.courseName;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppConstants.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.outline),
                        ),
                        child: Text(
                          '$shortName: ${c.cie}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.find_in_page_rounded,
                          size: 15,
                          color: AppConstants.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View subject CIE, Mid, Lab & End-Term marks',
                          style: AppConstants.getBodyMedium(
                            color: AppConstants.primary,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppConstants.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusButton),
        border: Border.all(color: AppConstants.outline),
        boxShadow: AppConstants.shadowLevel1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: accentColor),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppConstants.textSecondary,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppConstants.getLabelSmall()),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppConstants.getHeadline().copyWith(fontSize: 16),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppConstants.getBodyMedium(
                        color: AppConstants.textSecondary,
                      ).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoModal(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surface,
        title: Text(
          title,
          style: AppConstants.getHeadline(color: AppConstants.primary),
        ),
        content: Text(message, style: AppConstants.getBodyLarge()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMentorModal(String mentorName, String mentorContact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surface,
        title: Text(
          'Faculty Mentor',
          style: AppConstants.getHeadline(color: AppConstants.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mentorName,
              style: AppConstants.getHeadline().copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Contact: $mentorContact',
              style: AppConstants.getBodyMedium(
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (RegExp(r'\d{8,}').hasMatch(mentorContact))
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mentorContact));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mentor phone number copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Number'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickReconnectSheet() async {
    final creds = await SecureSessionStore.getSession(
      role: 'sraap_credentials',
    );
    final roll = (creds?['sraap_roll']?.toString() ??
            StorageService.getStudentRollNumber() ??
            '')
        .trim()
        .toUpperCase();
    final pass = creds?['sraap_pass']?.toString() ?? '';

    if (!mounted) return;

    if (roll.isEmpty || pass.isEmpty) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
          )
          .then((_) => _loadData(forceRefresh: true));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickReconnectModal(
        rollNumber: roll,
        password: pass,
        onSuccess: () {
          Navigator.of(ctx).pop();
          _loadData(forceRefresh: true);
        },
      ),
    );
  }
}

class _QuickReconnectModal extends StatefulWidget {
  final String rollNumber;
  final String password;
  final VoidCallback onSuccess;

  const _QuickReconnectModal({
    required this.rollNumber,
    required this.password,
    required this.onSuccess,
  });

  @override
  State<_QuickReconnectModal> createState() => _QuickReconnectModalState();
}

class _QuickReconnectModalState extends State<_QuickReconnectModal> {
  final TextEditingController _captchaCtrl = TextEditingController();
  bool _isLoadingCaptcha = true;
  bool _isSubmitting = false;
  Uint8List? _captchaBytes;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    SraapSessionManager.instance.isLoginFlowActive = true;
    _fetchCaptcha(forceFreshSession: true);
  }

  @override
  void dispose() {
    SraapSessionManager.instance.isLoginFlowActive = false;
    _captchaCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCaptcha({bool forceFreshSession = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingCaptcha = true;
    });

    final bytes = await SraapSessionManager.instance.fetchCaptcha(
      forceFreshSession: forceFreshSession,
    );

    if (mounted) {
      setState(() {
        _captchaBytes = bytes;
        _isLoadingCaptcha = false;
        if (bytes == null) {
          _errorMsg ??= 'Could not load CAPTCHA. Tap image to reload.';
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isLoadingCaptcha) return;

    final code = _captchaCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMsg = 'Please enter the CAPTCHA code.');
      return;
    }

    if (_captchaBytes == null) {
      setState(
        () => _errorMsg = 'CAPTCHA not loaded yet. Tap image to reload.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    try {
      final result = await SraapAuthManager.submitLogin(
        enrollment: widget.rollNumber.trim().toUpperCase(),
        password: widget.password,
        captcha: code,
      );

      if (!mounted) return;

      if (result.success) {
        await StorageService.setSraapConnected(true);
        await SraapSessionManager.instance.markAuthenticated();
        SraapAcademicService.instance.startKeepAlive();
        widget.onSuccess();
      } else {
        switch (result.error) {
          case SraapLoginError.portalUnavailable:
            setState(
              () => _errorMsg =
                  'SRAAP access is temporarily restricted on this network. Please switch to Mobile Data (4G/5G).',
            );
            break;
          case SraapLoginError.invalidCaptcha:
            setState(() => _errorMsg = 'Incorrect CAPTCHA. Please try again.');
            _captchaCtrl.clear();
            await _fetchCaptcha(forceFreshSession: false);
            break;
          case SraapLoginError.invalidCredentials:
            setState(
              () => _errorMsg =
                  'Stored password could not be verified. Please reconnect your account below.',
            );
            break;
          case SraapLoginError.timeout:
          case SraapLoginError.networkUnavailable:
            setState(
              () => _errorMsg =
                  'Unable to reach SRAAP. Check your connection and try again.',
            );
            break;
          case SraapLoginError.sessionExpired:
          case SraapLoginError.unknown:
          case null:
            setState(
              () => _errorMsg =
                  'Verification failed. Enter the new CAPTCHA to retry.',
            );
            _captchaCtrl.clear();
            await _fetchCaptcha(forceFreshSession: true);
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Connection error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppConstants.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppConstants.shadowLevel2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppConstants.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.sync_lock_rounded,
                  color: AppConstants.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Renew SRAAP Session',
                  style: AppConstants.getHeadline(
                    color: AppConstants.primary,
                  ).copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your university session timed out. Solve the CAPTCHA code below to instantly refresh your attendance & marks.',
              style: AppConstants.getBodyMedium(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppConstants.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppConstants.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Roll No: ${widget.rollNumber.trim().toUpperCase()}',
                    style: AppConstants.getBodyMedium().copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: (_isLoadingCaptcha || _isSubmitting)
                      ? null
                      : () {
                          setState(() => _errorMsg = null);
                          _fetchCaptcha(forceFreshSession: false);
                        },
                  child: Container(
                    height: 52,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.outline),
                    ),
                    child: _isLoadingCaptcha
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _captchaBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _captchaBytes!,
                                  fit: BoxFit.fill,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(
                                      Icons.refresh,
                                      color: AppConstants.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.refresh,
                                  color: AppConstants.primary,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _captchaCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    cursorColor: AppConstants.primary,
                    style: AppConstants.getBodyLarge(
                      color: AppConstants.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      hintStyle: AppConstants.getBodyMedium(
                        color: AppConstants.textMuted,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMsg!,
                style: AppConstants.getBodyMedium(
                  color: AppConstants.error,
                ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (_errorMsg!.contains('reconnect')) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const AcademicLoginScreen(),
                            ),
                          )
                          .then((_) => widget.onSuccess());
                    },
                    child: const Text('Sign In to SRAAP Manually'),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppConstants.primary,
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('https://sraap.in/student_login.php');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: const Text('Open Official SRAAP in Browser'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: AppConstants.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusButton,
                  ),
                ),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.onPrimary,
                      ),
                    )
                  : const Text(
                      'VERIFY & REFRESH',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
