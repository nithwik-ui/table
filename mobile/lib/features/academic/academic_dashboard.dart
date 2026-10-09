import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/sraap/sraap_academic_service.dart';
import '../../core/sraap/models/sraap_academic_data.dart';
import 'academic_login_screen.dart';
import 'attendance_screen.dart';

class AcademicDashboard extends StatefulWidget {
  const AcademicDashboard({super.key});

  @override
  State<AcademicDashboard> createState() => _AcademicDashboardState();
}

class _AcademicDashboardState extends State<AcademicDashboard> {
  bool _isLoading = true;
  bool _isSyncing = false;
  SraapAcademicData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (_data == null) {
      final cached = SraapAcademicService.instance.getCachedAcademicData();
      if (cached != null) {
        _data = cached;
        _isLoading = false;
      }
    }

    if (mounted) {
      setState(() {
        if (!forceRefresh && _data == null) _isLoading = true;
        _isSyncing = forceRefresh;
        _error = null;
      });
    }

    try {
      final data = await SraapAcademicService.instance.getAcademicData(forceRefresh: forceRefresh);
      if (mounted && data != null) {
        setState(() {
          _data = data;
          _isLoading = false;
          _isSyncing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final cached = SraapAcademicService.instance.getCachedAcademicData();
        setState(() {
          if (_data == null && cached != null) {
            _data = cached;
            _error = null;
          } else if (_data == null) {
            _error = 'Unable to connect to SRAAP.';
          }
          _isLoading = false;
          _isSyncing = false;
        });
      }
    }
  }

  String _formatTimeAgo(DateTime time) {
    final now = TimeUtils.getKolkataTime();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    if (diff.inHours < 24 && time.day == now.day) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour >= 12 ? 'PM' : 'AM';
      return 'Last updated today at $hour:$minute $ampm';
    }
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
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
              ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
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
            const Icon(Icons.school_outlined, size: 48, color: AppConstants.textSecondary),
            const SizedBox(height: 16),
            Text(_error ?? 'Not connected to SRAAP.', style: AppConstants.getBodyLarge(color: AppConstants.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusButton)),
              ),
              icon: const Icon(Icons.link),
              label: const Text('Connect SRAAP', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
                ).then((_) => _loadData());
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
        ? AppConstants.success
        : isCondonation
            ? AppConstants.warning
            : AppConstants.error;
    final badgeBg = isSafe
        ? AppConstants.successContainer
        : isCondonation
            ? AppConstants.warningContainer
            : AppConstants.errorContainer;
    final statusText = isSafe
        ? 'Safe / Eligible'
        : isCondonation
            ? 'Condonation Zone'
            : 'Low Attendance';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 14),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Space',
                  style: AppConstants.getDisplay(color: AppConstants.primary).copyWith(fontSize: 22),
                ),
                const SizedBox(height: 2),
                Text(
                  'SRAAP • ${_formatTimeAgo(data.lastSynced)}',
                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                ),
              ],
            ),
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary),
                    )
                  : const Icon(Icons.refresh_rounded, color: AppConstants.primary),
              onPressed: _isSyncing ? null : () => _loadData(forceRefresh: true),
              tooltip: 'Sync Academic Data',
            ),
          ],
        ),

        const SizedBox(height: 20),

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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ).then((_) => _loadData());
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
                                borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                              ),
                              child: Icon(Icons.bar_chart_rounded, color: statusColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OVERALL ATTENDANCE',
                                  style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${attendance.toStringAsFixed(1)}%',
                                      style: AppConstants.getDisplay(color: statusColor).copyWith(fontSize: 26),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '/ 100%',
                                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          ),
                          child: Text(
                            statusText,
                            style: AppConstants.getLabelSmall(color: statusColor).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                      child: LinearProgressIndicator(
                        value: (attendance / 100).clamp(0.0, 1.0),
                        backgroundColor: AppConstants.outline.withOpacity(0.5),
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
                            const Icon(Icons.touch_app_rounded, size: 14, color: AppConstants.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to view subject breakdown',
                              style: AppConstants.getBodyMedium(color: AppConstants.primary).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppConstants.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Academic Hub',
          style: AppConstants.getHeadline().copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),

        // Simplified Grid of Academic Options
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            // Option 1: Attendance
            _buildOptionCard(
              icon: Icons.fact_check_outlined,
              title: 'Attendance',
              value: '${attendance.toStringAsFixed(1)}%',
              subtitle: 'Subject breakdown',
              accentColor: statusColor,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ).then((_) => _loadData());
              },
            ),

            // Option 2: CGPA
            _buildOptionCard(
              icon: Icons.bar_chart_rounded,
              title: 'CGPA',
              value: cgpa,
              subtitle: 'Out of 10.0',
              accentColor: AppConstants.info,
              onTap: () {
                _showInfoModal('CGPA', 'Current Cumulative GPA is $cgpa / 10.0.');
              },
            ),

            // Option 3: Mentor
            _buildOptionCard(
              icon: Icons.person_outline_rounded,
              title: 'Mentor',
              value: mentorName.split(' ').first,
              subtitle: mentorDept,
              accentColor: AppConstants.success,
              onTap: () {
                _showInfoModal('Faculty Mentor', 'Mentor: $mentorName\nDetails: $mentorDept');
              },
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
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
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: accentColor),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppConstants.textSecondary),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppConstants.getLabelSmall(),
                    ),
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
                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(fontSize: 11),
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
        title: Text(title, style: AppConstants.getHeadline(color: AppConstants.primary)),
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
}
