import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/sraap/sraap_academic_service.dart';
import '../../core/sraap/sraap_session_manager.dart';
import '../../core/sraap/models/sraap_academic_data.dart';

class InternalMarksScreen extends StatefulWidget {
  const InternalMarksScreen({super.key});

  @override
  State<InternalMarksScreen> createState() => _InternalMarksScreenState();
}

class _InternalMarksScreenState extends State<InternalMarksScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isShowingFresh = false;
  bool _isOffline = false;
  String? _errorMessage;

  SraapInternalMarksData? _data;
  String _selectedSem = 'All';

  @override
  void initState() {
    super.initState();
    _loadMarks();
  }

  Future<void> _loadMarks({bool forceRefresh = false}) async {
    final cached = SraapAcademicService.instance.getCachedInternalMarks();
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

    if (StorageService.isSraapConnected()) {
      try {
        final fresh = await SraapAcademicService.instance.fetchInternalMarks(
          forceRefresh: true,
        );
        if (mounted && fresh != null) {
          setState(() {
            _data = fresh;
            _isLoading = false;
            _isRefreshing = false;
            _isOffline = false;
            _isShowingFresh = true;
          });
          // Prefetch details for courses in background if not yet cached
          _prefetchCourseDetailsSilently(fresh.courses);
          return;
        }
      } catch (e) {
        debugPrint('[SRAAP] Internal marks load error: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      if (_data == null) {
        final c = SraapAcademicService.instance.getCachedInternalMarks();
        if (c != null) {
          _data = c;
          _isOffline = true;
        } else {
          _errorMessage =
              'Could not load Examination Marks from SRAAP. Please check your connection or renew your SRAAP session.';
        }
      } else {
        _isOffline = true;
      }
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _prefetchCourseDetailsSilently(
    List<SraapCourseMarks> courses,
  ) async {
    for (final c in courses) {
      if (!mounted) return;
      if (c.components.isEmpty &&
          ((c.detailHref != null && c.detailHref!.isNotEmpty) ||
              (c.formAction != null && c.formAction!.isNotEmpty))) {
        try {
          await SraapAcademicService.instance.fetchCourseMarksDetail(c);
          final updated = SraapAcademicService.instance.getCachedInternalMarks();
          if (mounted && updated != null) {
            setState(() => _data = updated);
          }
        } catch (_) {}
      }
    }
  }

  String _formatLastUpdated(DateTime? dateTime) {
    if (dateTime == null) return 'Never updated';
    final now = TimeUtils.getKolkataTime();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    if (diff.inHours < 24 && dateTime.day == now.day) {
      return 'Updated today at $hour:$minute $ampm';
    }
    return 'Updated ${dateTime.day}/${dateTime.month} at $hour:$minute $ampm';
  }

  IconData _getSubjectIcon(String subjectName) {
    final lower = subjectName.toLowerCase();
    if (lower.contains('software') ||
        lower.contains('system') ||
        lower.contains('web') ||
        lower.contains('cloud')) {
      return Icons.laptop_chromebook_rounded;
    } else if (lower.contains('algorithm') ||
        lower.contains('data struct') ||
        lower.contains('program') ||
        lower.contains('java') ||
        lower.contains('python')) {
      return Icons.code_rounded;
    } else if (lower.contains('ai') ||
        lower.contains('intelligence') ||
        lower.contains('learning') ||
        lower.contains('deep')) {
      return Icons.psychology_rounded;
    } else if (lower.contains('skill') ||
        lower.contains('interpersonal') ||
        lower.contains('critical') ||
        lower.contains('english')) {
      return Icons.group_rounded;
    } else if (lower.contains('stat') ||
        lower.contains('math') ||
        lower.contains('probability')) {
      return Icons.analytics_outlined;
    }
    return Icons.menu_book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: AppConstants.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppConstants.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sem Wise CIE / ETE',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppConstants.primary,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'SRAAP • Internal Examination Marks',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppConstants.primary,
                    ),
                  )
                : Icon(Icons.refresh_rounded, color: AppConstants.primary),
            tooltip: 'Refresh Marks',
            onPressed: _isRefreshing
                ? null
                : () => _loadMarks(forceRefresh: true),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppConstants.primary,
          onRefresh: () => _loadMarks(forceRefresh: true),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppConstants.primary),
      );
    }

    if (_errorMessage != null && _data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.assignment_late_outlined,
            size: 48,
            color: AppConstants.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppConstants.getBodyMedium(
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _loadMarks(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: AppConstants.onPrimary,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final courses = _data?.courses ?? const [];
    if (courses.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.school_outlined,
            size: 48,
            color: AppConstants.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No CIE / ETE marks published yet on SRAAP.',
            textAlign: TextAlign.center,
            style: AppConstants.getHeadline().copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh once your faculty uploads Mid or Internal marks.',
            textAlign: TextAlign.center,
            style: AppConstants.getBodyMedium(
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      );
    }

    final semesters = _data!.availableSemesters;
    final filteredCourses = _selectedSem == 'All'
        ? courses
        : courses.where((c) => c.yearSem.trim() == _selectedSem).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (_isOffline || SraapSessionManager.instance.isSessionExpired)
          _buildOfflineBanner(),
        _buildOverviewCard(filteredCourses, _data!.lastSynced),
        if (semesters.length > 1) ...[
          const SizedBox(height: 14),
          _buildSemesterFilterChips(semesters),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Examination Marks (${filteredCourses.length})',
              style: AppConstants.getHeadline().copyWith(fontSize: 16),
            ),
            Text(
              'Tap subject for details',
              style: AppConstants.getLabelSmall(
                color: AppConstants.primary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...filteredCourses.map(_buildCourseMarksCard),
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
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppConstants.warningText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cached • Showing saved marks from SRAAP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppConstants.warningText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _loadMarks(forceRefresh: true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Refresh',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppConstants.warningText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    List<SraapCourseMarks> courses,
    DateTime lastSynced,
  ) {
    final totalCie = courses.fold<double>(0.0, (s, c) => s + c.cieScore);
    final avgCie = courses.isNotEmpty ? (totalCie / courses.length) : 0.0;
    final highest = courses.isNotEmpty
        ? courses.map((c) => c.cieScore).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final semLabel = courses.isNotEmpty && courses.first.yearSem.isNotEmpty
        ? 'Sem ${courses.first.yearSem}'
        : 'Current Sem';

    final isStale = _isOffline ||
        SraapSessionManager.instance.isSessionExpired ||
        !_isShowingFresh;

    return Container(
      padding: const EdgeInsets.all(16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: AppConstants.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'CIE Internal Summary',
                                  style: AppConstants.getHeadline().copyWith(
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isStale
                                      ? AppConstants.warningContainer
                                      : AppConstants.successContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isStale ? 'Cached' : 'Fresh',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isStale
                                        ? AppConstants.warningText
                                        : AppConstants.successText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatLastUpdated(lastSynced),
                            style: AppConstants.getLabelSmall(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  semLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatMiniBox(
                  label: 'Avg CIE',
                  value: avgCie.toStringAsFixed(1),
                  sub: 'Per subject',
                  color: AppConstants.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatMiniBox(
                  label: 'Total CIE',
                  value: totalCie.truncateToDouble() == totalCie
                      ? totalCie.toInt().toString()
                      : totalCie.toStringAsFixed(1),
                  sub: '${courses.length} courses',
                  color: AppConstants.successText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatMiniBox(
                  label: 'Highest CIE',
                  value: highest.truncateToDouble() == highest
                      ? highest.toInt().toString()
                      : highest.toStringAsFixed(1),
                  sub: 'Top score',
                  color: AppConstants.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMiniBox({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppConstants.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10.5,
              color: AppConstants.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterFilterChips(List<String> semesters) {
    final options = ['All', ...semesters];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final sem = options[i];
          final selected = _selectedSem == sem;
          return ChoiceChip(
            label: Text(sem == 'All' ? 'All Semesters' : 'Sem $sem'),
            selected: selected,
            onSelected: (_) => setState(() => _selectedSem = sem),
            selectedColor: AppConstants.primary,
            backgroundColor: AppConstants.surface,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppConstants.onPrimary
                  : AppConstants.textPrimary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourseMarksCard(SraapCourseMarks course) {
    final cieVal = course.cieScore;
    final Color cieColor = cieVal >= 15
        ? AppConstants.successText
        : (cieVal >= 10 ? AppConstants.warningText : AppConstants.errorText);
    final Color cieBg = cieVal >= 15
        ? AppConstants.successContainer
        : (cieVal >= 10
              ? AppConstants.warningContainer
              : AppConstants.errorContainer);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.outline),
        boxShadow: AppConstants.shadowLevel1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCourseMarksDetailSheet(course),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSubjectIcon(course.courseName),
                        color: AppConstants.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (course.courseCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppConstants.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppConstants.outline,
                                    ),
                                  ),
                                  child: Text(
                                    course.courseCode,
                                    style: AppConstants.getMonoLabel(
                                      color: AppConstants.textSecondary,
                                    ).copyWith(fontSize: 10),
                                  ),
                                ),
                              if (course.yearSem.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppConstants.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Sem ${course.yearSem}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppConstants.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            course.courseName,
                            style: AppConstants.getHeadline().copyWith(
                              fontSize: 14.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppConstants.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConstants.outline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: cieBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'CIE: ${course.cie}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: cieColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppConstants.outline),
                              ),
                              child: Text(
                                course.isEtePublished
                                    ? 'ETE: ${course.ete}'
                                    : 'ETE: ${course.ete} (Pending)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.find_in_page_rounded,
                            size: 16,
                            color: AppConstants.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: AppConstants.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (course.components.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: course.components
                        .where((c) => c.isEntered)
                        .take(4)
                        .map(
                          (comp) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.secondaryContainer.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${comp.cleanTitle}: ${comp.value}${comp.maxMarks != null ? '/${comp.maxMarks!.toInt()}' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppConstants.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCourseMarksDetailSheet(SraapCourseMarks course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CourseMarksDetailSheet(
        course: course,
        onUpdated: () {
          final updated = SraapAcademicService.instance.getCachedInternalMarks();
          if (mounted && updated != null) {
            setState(() => _data = updated);
          }
        },
      ),
    );
  }
}

class _CourseMarksDetailSheet extends StatefulWidget {
  final SraapCourseMarks course;
  final VoidCallback onUpdated;

  const _CourseMarksDetailSheet({
    required this.course,
    required this.onUpdated,
  });

  @override
  State<_CourseMarksDetailSheet> createState() =>
      _CourseMarksDetailSheetState();
}

class _CourseMarksDetailSheetState extends State<_CourseMarksDetailSheet> {
  late List<SraapAssessmentComponent> _components;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _components = widget.course.components;
    _fetchLatestDetails();
  }

  Future<void> _fetchLatestDetails() async {
    if (_components.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final fetched = await SraapAcademicService.instance
          .fetchCourseMarksDetail(widget.course);
      if (mounted) {
        setState(() {
          if (fetched.isNotEmpty) {
            _components = fetched;
          }
          _isLoading = false;
        });
        widget.onUpdated();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<SraapAssessmentComponent> _getDisplayComponents() {
    if (_components.isNotEmpty) return _components;
    return [
      SraapAssessmentComponent(
        label: 'Mid Term Examination (20)',
        value: widget.course.cie,
      ),
      const SraapAssessmentComponent(label: 'Lab Exam (10)', value: ''),
      const SraapAssessmentComponent(label: 'End Lab Exam (20)', value: ''),
      const SraapAssessmentComponent(label: 'Project (10)', value: ''),
      const SraapAssessmentComponent(label: 'Re Mid Marks', value: ''),
      SraapAssessmentComponent(
        label: 'End Term Examination (40)',
        value: widget.course.ete,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final displayComponents = _getDisplayComponents();
    final cieVal = widget.course.cieScore;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppConstants.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppConstants.shadowLevel2,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppConstants.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.analytics_outlined,
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
                                'Course : ${widget.course.courseName}${widget.course.courseCode.isNotEmpty ? ' (${widget.course.courseCode})' : ''}',
                                style: AppConstants.getHeadline().copyWith(
                                  fontSize: 15.5,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Semester ${widget.course.yearSem} • Detailed Assessment Breakdown',
                                style: AppConstants.getLabelSmall(
                                  color: AppConstants.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Summary Row: CIE & ETE
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppConstants.secondaryContainer.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppConstants.primary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current CIE Total',
                                  style: AppConstants.getLabelSmall(
                                    color: AppConstants.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.course.cie} / 60',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppConstants.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppConstants.outline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Term (ETE)',
                                  style: AppConstants.getLabelSmall(
                                    color: AppConstants.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.course.isEtePublished
                                      ? '${widget.course.ete} / 40'
                                      : '${widget.course.ete} (Pending)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Component Wise Marks',
                          style: AppConstants.getHeadline().copyWith(
                            fontSize: 15,
                          ),
                        ),
                        if (_isLoading)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppConstants.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...displayComponents.map(_buildComponentRow),

                    const SizedBox(height: 18),
                    _buildTargetEstimatorCard(cieVal),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComponentRow(SraapAssessmentComponent comp) {
    final max = comp.maxMarks;
    final scored = comp.scoredMarks;
    final entered = comp.isEntered;
    final isPendingEte = comp.isEndTerm && (scored == null || scored == 0);

    final double? pct = (max != null && max > 0 && scored != null && !isPendingEte)
        ? (scored / max).clamp(0.0, 1.0)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entered && !isPendingEte
              ? AppConstants.primary.withValues(alpha: 0.35)
              : AppConstants.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  comp.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: entered && !isPendingEte
                      ? AppConstants.successContainer
                      : AppConstants.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: entered && !isPendingEte
                      ? null
                      : Border.all(color: AppConstants.outline),
                ),
                child: Text(
                  entered
                      ? (max != null
                            ? '${comp.value} / ${max.toInt()}'
                            : comp.value)
                      : (max != null ? '— / ${max.toInt()}' : 'Not Entered'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: entered && !isPendingEte
                        ? AppConstants.successText
                        : AppConstants.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (pct != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppConstants.outline,
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 0.75
                      ? AppConstants.successText
                      : (pct >= 0.5
                            ? AppConstants.primary
                            : AppConstants.warningText),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetEstimatorCard(double currentCie) {
    // Total course marks = 100 (60 CIE + 40 ETE). Pass marks = 45!
    final targets = [
      ('Pass (45 Total)', 45.0),
      ('First Class / B+ (60 Total)', 60.0),
      ('Distinction / A (70 Total)', 70.0),
      ('A+ Grade (80 Total)', 80.0),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: AppConstants.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Remaining Marks Needed (Out of 100)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Based on your current CIE (${currentCie.toStringAsFixed(0)} marks), here is what you need across remaining internals + End-Term to reach Pass (45):',
            style: TextStyle(
              fontSize: 11.5,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ...targets.map((t) {
            final needed = (t.$2 - currentCie).clamp(0.0, 100.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  Text(
                    needed <= 0
                        ? 'Achieved!'
                        : '+${needed.toInt()} marks needed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: needed <= 0
                          ? AppConstants.successText
                          : AppConstants.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
