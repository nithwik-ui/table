import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants.dart';
import '../../core/sync.dart';
import '../../core/storage.dart';
import 'dart:convert';

class NotificationDiagnosticsScreen extends StatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  State<NotificationDiagnosticsScreen> createState() => _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState extends State<NotificationDiagnosticsScreen> {
  bool _isLoading = true;
  int _pendingCount = 0;
  String _fcmToken = 'Fetching...';
  List<PendingNotificationRequest> _pendingRequests = [];
  bool _notificationPermission = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    bool hasPermission = false;
    if (androidPlugin != null) {
      hasPermission = await androidPlugin.areNotificationsEnabled() ?? false;
    }
    
    String fcm = 'Not registered';
    try {
      final token = await FirebaseMessaging.instance.getToken();
      fcm = token != null ? '✓ Registered (${token.substring(0, 8)}...)' : 'Not registered';
    } catch (_) {}

    final pending = await plugin.pendingNotificationRequests();
    
    setState(() {
      _notificationPermission = hasPermission;
      _fcmToken = fcm;
      _pendingCount = pending.length;
      _pendingRequests = pending;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppConstants.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userMode = StorageService.getUserMode();
    final syncState = SyncService.instance.syncState;
    final lastSynced = userMode == 'faculty' ? StorageService.getFacultyLastSyncedAt() : StorageService.getLastSyncedAt();

    Map<String, dynamic>? nextReminder;
    if (_pendingRequests.isNotEmpty) {
      // Find nearest class reminder
      try {
        final sorted = List.of(_pendingRequests)..sort((a, b) {
          // Attempt to extract scheduledFor if possible, fallback to ID order
          return a.id.compareTo(b.id);
        });
        
        for (var p in sorted) {
          if (p.payload != null) {
            final data = jsonDecode(p.payload!);
            if (data['type'] == 'class_reminder') {
              nextReminder = {
                'title': p.title,
                'body': p.body,
                'time': data['date'], // Real time not stored in PendingNotificationRequest unfortunately unless encoded
              };
              break;
            }
          }
        }
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: Text('Diagnostics', style: AppConstants.getHeadline().copyWith(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingContainer),
        children: [
          _buildItem('Notifications', _notificationPermission ? '✓ Permission enabled' : '⚠ Permission disabled'),
          _buildItem('FCM', _fcmToken),
          _buildItem('Current mode', userMode ?? 'None'),
          _buildItem('Network state', syncState.toString().split('.').last),
          _buildItem('Last sync', lastSynced != null ? '✓ ${lastSynced.hour}:${lastSynced.minute}' : 'Never'),
          
          const SizedBox(height: 24),
          Text('Local Reminders', style: AppConstants.getHeadline().copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          _buildItem('Status', '✓ Active'),
          _buildItem('Scheduled', '$_pendingCount'),
          
          if (nextReminder != null) ...[
            const SizedBox(height: 16),
            Text('Next Reminder:', style: AppConstants.getHeadline().copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(nextReminder['body'] ?? '', style: AppConstants.getBodyMedium()),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: AppConstants.getBodyMedium().copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
