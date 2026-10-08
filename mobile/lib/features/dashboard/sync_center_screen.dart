import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/sync.dart';
import '../../core/storage.dart';

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
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final syncState = SyncService.instance.syncState;
    final isSyncing = SyncService.instance.isSyncing;
    final userMode = StorageService.getUserMode();
    final lastSynced = userMode == 'faculty' ? StorageService.getFacultyLastSyncedAt() : StorageService.getLastSyncedAt();
    final lastChecked = SyncService.instance.lastCheckedAt ?? lastSynced;

    String networkStatus;
    IconData networkIcon;
    Color networkColor;

    if (syncState == SyncState.offline) {
      networkStatus = '⚠ Offline';
      networkIcon = Icons.cloud_off;
      networkColor = AppConstants.warning;
    } else if (syncState == SyncState.serverUnavailable) {
      networkStatus = '⚠ SRU server temporarily unavailable';
      networkIcon = Icons.cloud_off;
      networkColor = AppConstants.error;
    } else if (syncState == SyncState.syncTimeout) {
      networkStatus = '⚠ Sync timeout';
      networkIcon = Icons.cloud_off;
      networkColor = AppConstants.error;
    } else {
      networkStatus = '✓ Connected';
      networkIcon = Icons.cloud_done;
      networkColor = AppConstants.success;
    }

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: Text('Sync Center', style: AppConstants.getHeadline().copyWith(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingContainer),
        children: [
          _buildCard(
            title: 'Network',
            icon: networkIcon,
            color: networkColor,
            subtitle: networkStatus,
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Timetable',
            icon: Icons.calendar_today,
            color: AppConstants.primary,
            subtitle: syncState == SyncState.offline || syncState != SyncState.online 
                ? '✓ Using cached timetable'
                : '✓ Last successful sync: ${_formatDate(lastSynced)}',
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Changes',
            icon: Icons.history,
            color: AppConstants.primary,
            subtitle: '✓ Last checked: ${_formatDate(lastChecked)}',
          ),
          const SizedBox(height: 24),
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
