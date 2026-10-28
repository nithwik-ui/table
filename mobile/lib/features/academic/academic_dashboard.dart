import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/auth/secure_session_store.dart';
import '../../core/sraap/sraap_session_manager.dart';
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
  bool _isSessionExpired = false;
  SraapAcademicData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isSessionExpired = SraapSessionManager.instance.isSessionExpired;
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // 1. Immediately render cached data if available
    final cached = SraapAcademicService.instance.getCachedAcademicData();
    if (cached != null && _data == null) {
      _data = cached;
      _isLoading = false;
    }

    if (mounted) {
      setState(() {
        if (_data == null) _isLoading = true;
        _isSyncing = true;
        _error = null;
        _isSessionExpired = SraapSessionManager.instance.isSessionExpired;
      });
    }

    // 2. Fetch live data from the main SRAAP page
    if (StorageService.isSraapConnected()) {
      try {
        final fresh = await SraapAcademicService.instance.getAcademicData(forceRefresh: forceRefresh);
        if (mounted && fresh != null) {
          setState(() {
            _data = fresh;
            _isLoading = false;
            _isSyncing = false;
            _isSessionExpired = false;
          });
          if (forceRefresh) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Attendance updated from SRAAP'),
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
          });
          return;
        }
      } catch (e) {
        debugPrint('[SRAAP] Live dashboard fetch error: $e');
        if (mounted && forceRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not reach SRAAP. Showing saved attendance.'),
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
    final statusColor = AppConstants.primary;
    final badgeBg = AppConstants.secondaryContainer;
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
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isSessionExpired) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppConstants.warningContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
              border: Border.all(color: AppConstants.warning.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppConstants.warning, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SRAAP Session Expired',
                        style: AppConstants.getBodyMedium(color: AppConstants.textPrimary).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap RENEW to enter CAPTCHA and refresh live attendance.',
                        style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _showQuickReconnectSheet,
                  child: const Text('RENEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                        backgroundColor: AppConstants.outline.withValues(alpha: 0.5),
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
                        color: accentColor.withValues(alpha: 0.12),
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

  Future<void> _showQuickReconnectSheet() async {
    final creds = await SecureSessionStore.getSession(role: 'sraap_credentials');
    final roll = creds?['sraap_roll']?.toString() ?? StorageService.getStudentRollNumber() ?? '';
    final pass = creds?['sraap_pass']?.toString() ?? '';

    if (!mounted) return;

    if (roll.isEmpty || pass.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
      ).then((_) => _loadData(forceRefresh: true));
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
          _loadData();
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
    _fetchCaptcha();
  }

  @override
  void dispose() {
    _captchaCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCaptcha() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCaptcha = true;
      _errorMsg = null;
    });

    final bytes = await SraapSessionManager.instance.fetchCaptcha(forceFreshSession: true);

    if (mounted) {
      setState(() {
        _captchaBytes = bytes;
        _isLoadingCaptcha = false;
        if (bytes == null) {
          _errorMsg = 'Could not load CAPTCHA. Tap image to reload.';
        }
      });
    }
  }

  Future<void> _submit() async {
    final code = _captchaCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMsg = 'Please enter the CAPTCHA code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    try {
      final res = await SraapSessionManager.instance.login(
        enrollment: widget.rollNumber,
        password: widget.password,
        captcha: code,
      );

      final body = res.body.toLowerCase();
      final bool isSuccess = res.statusCode == 302 ||
          res.statusCode == 301 ||
          (res.statusCode == 200 &&
              (body.contains('logout') ||
               body.contains('attendancetable') ||
               body.contains('welcome to')) &&
              !body.contains('student_login'));

      if (isSuccess) {
        // Success
        await StorageService.setSraapConnected(true);
        SraapSessionManager.instance.isSessionExpired = false;
        SraapAcademicService.instance.startKeepAlive();
        widget.onSuccess();
      } else if (body.contains('access restricted') || body.contains('shared public ip')) {
        setState(() => _errorMsg = 'SRAAP access is temporarily restricted on this network. Please switch to Mobile Data (4G/5G).');
      } else if (body.contains('enter captcha code') || body.contains('invalid captcha')) {
        setState(() => _errorMsg = 'Incorrect CAPTCHA. Please try again.');
        _captchaCtrl.clear();
        _fetchCaptcha();
      } else if (body.contains("sorry, i don't recognize you") ||
          body.contains('recheck') ||
          body.contains('wrong password') ||
          body.contains('forgot / reset password')) {
        setState(() => _errorMsg = 'Stored password could not be verified. Please reconnect your account below.');
      } else {
        setState(() => _errorMsg = 'Verification failed. Tap CAPTCHA to refresh and retry.');
        _captchaCtrl.clear();
        _fetchCaptcha();
      }
    } catch (e) {
      setState(() => _errorMsg = 'Connection error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                const Icon(Icons.sync_lock_rounded, color: AppConstants.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Renew SRAAP Session',
                  style: AppConstants.getHeadline(color: AppConstants.primary).copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your university session timed out. Solve the CAPTCHA code below to instantly refresh your attendance.',
              style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
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
                  const Icon(Icons.person_outline, size: 18, color: AppConstants.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Roll No: ${widget.rollNumber}',
                    style: AppConstants.getBodyMedium().copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: _fetchCaptcha,
                  child: Container(
                    height: 52,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.outline),
                    ),
                    child: _isLoadingCaptcha
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : _captchaBytes != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_captchaBytes!, fit: BoxFit.fill))
                            : const Center(child: Icon(Icons.refresh, color: AppConstants.primary)),
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
                    decoration: const InputDecoration(
                      hintText: 'Enter code',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                style: AppConstants.getBodyMedium(color: AppConstants.error).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (_errorMsg!.contains('reconnect')) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
                      ).then((_) => widget.onSuccess());
                    },
                    child: const Text('Sign In to SRAAP Manually'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusButton)),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('VERIFY & REFRESH ATTENDANCE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
