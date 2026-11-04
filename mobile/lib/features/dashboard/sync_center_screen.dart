import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/sync.dart';
import '../../core/storage.dart';
import '../../core/auth/auth_repository.dart';
import '../onboarding/sru_login_screen.dart';
import '../onboarding/sru_otp_screen.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  @override
  void initState() {
    super.initState();
    SyncService.instance.addListener(_updateState);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Never';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final syncState = SyncService.instance.syncState;
    final isSyncing = SyncService.instance.isSyncing;
    final lastChecked = SyncService.instance.lastCheckedAt;

    String statusText = 'Online';
    Color statusColor = AppConstants.success;
    IconData statusIcon = Icons.cloud_done;

    if (syncState == SyncState.offline) {
      statusText = 'Offline (Check connection)';
      statusColor = AppConstants.error;
      statusIcon = Icons.cloud_off;
    } else if (syncState == SyncState.serverUnavailable) {
      statusText = 'University Portal Unavailable';
      statusColor = AppConstants.warning;
      statusIcon = Icons.cloud_queue;
    } else if (syncState == SyncState.syncTimeout) {
      statusText = 'Sync Timed Out';
      statusColor = AppConstants.warning;
      statusIcon = Icons.timer_off;
    } else if (syncState == SyncState.sessionExpired) {
      statusText = 'Session Expired';
      statusColor = AppConstants.error;
      statusIcon = Icons.lock_clock;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Center'),
        backgroundColor: AppConstants.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            title: 'Overall Status',
            icon: statusIcon,
            color: statusColor,
            subtitle: statusText,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Timetable Sync',
            icon: Icons.calendar_month,
            color: AppConstants.primary,
            subtitle: isSyncing ? 'Syncing...' : '✓ Last checked: ${_formatDate(lastChecked)}',
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Changes',
            icon: Icons.history,
            color: AppConstants.primary,
            subtitle: '✓ Last checked: ${_formatDate(lastChecked)}',
          ),
          const SizedBox(height: 24),
          if (syncState == SyncState.sessionExpired)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusButton)),
              ),
              onPressed: () async {
                final currentRole = StorageService.getUserMode() ?? 'student';
                final hasSaved = await AuthRepository.instance.hasSavedCredentials(role: currentRole);
                if (hasSaved) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Requesting OTP from university portal...'), duration: Duration(seconds: 2)),
                  );
                  final res = await AuthRepository.instance.renewSessionWithOtp(role: currentRole);
                  if (!context.mounted) return;
                  if (res['status'] == 'otp_required') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SruOtpScreen()),
                    );
                    return;
                  } else if (res['status'] == 'authenticated') {
                    SyncService.instance.syncTimetable(force: true);
                    return;
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message']?.toString() ?? 'Unable to renew session.')),
                    );
                  }
                }
                if (!context.mounted) return;
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SruLoginScreen(role: currentRole)), 
                );
                if (result == true) {
                  SyncService.instance.syncTimetable(force: true);
                }
              },
              child: const Text('Renew Session with OTP', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusButton)),
              ),
              onPressed: isSyncing ? null : () => SyncService.instance.syncTimetable(),
              child: isSyncing 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        boxShadow: AppConstants.shadowLevel1,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppConstants.getHeadline().copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
