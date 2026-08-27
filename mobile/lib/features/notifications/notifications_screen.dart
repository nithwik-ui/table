import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/api.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotificationHistory();
  }

  Future<void> _loadNotificationHistory() async {
    final selection = StorageService.getSelection();
    if (selection == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No batch selected. Please configure your timetable.';
      });
      return;
    }

    final batchId = selection['batchId']!;
    final batchCode = selection['batchCode']!;

    try {
      final changes = await ApiService.fetchChanges(batchId);
      final List<Map<String, dynamic>> parsedList = [];

      for (final change in changes) {
        final type = change['change_type'] as String;
        final oldVal = change['old_value'] as String? ?? '';
        final newVal = change['new_value'] as String? ?? '';
        final detectedAt = change['detected_at'] as String;

        String title = '';
        String body = '';

        // Decode subject from field_name if present (stored as "fieldName:SubjectName")
        String subject = 'Class';
        final fieldParts = (change['field_name'] as String? ?? '').split(':');
        if (fieldParts.length > 1) {
          subject = fieldParts.skip(1).join(':');
        }

        if (type == 'ROOM_CHANGED') {
          title = 'Room Changed';
          body = '$subject ($batchCode) moved to $newVal.';
        } else if (type == 'FACULTY_CHANGED') {
          title = 'Faculty Changed';
          body = '$subject will be taken by $newVal today.';
        } else if (type == 'CLASS_REMOVED') {
          title = 'Class Cancelled';
          final oldSubject = oldVal.split(' (')[0];
          body = '$oldSubject ($batchCode) has been cancelled for today.';
        } else if (type == 'CLASS_ADDED') {
          title = 'Class Added';
          final newSubject = newVal.split(' (')[0];
          body = '$newSubject ($batchCode) has been added.';
        } else if (type == 'TIME_CHANGED') {
          title = 'Class Rescheduled';
          body = '$subject rescheduled from $oldVal to $newVal.';
        } else {
          title = 'Schedule Update';
          body = '$subject details updated.';
        }

        parsedList.add({
          'id': change['id'] as String,
          'title': title,
          'body': body,
          'type': type,
          'timestamp': detectedAt,
          'read': true,
        });
      }

      // Add a simulated local class reminder notification if reminders are enabled, to showcase it visually
      if (StorageService.isClassRemindersEnabled() && parsedList.isNotEmpty) {
        final timetable = StorageService.getTimetableCache();
        if (timetable.isNotEmpty) {
          final firstClass = timetable.first;
          final room = (firstClass['room'] as String? ?? 'No Room').split('_')[0];
          parsedList.insert(0, {
            'id': 'simulated_reminder',
            'title': 'Class Reminder',
            'body': '${firstClass['subject']} starting in 15 mins ($room).',
            'type': 'CLASS_REMINDER',
            'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
            'read': false,
          });
        }
      }

      if (mounted) {
        setState(() {
          _notifications = parsedList;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not retrieve notifications. You are offline.';
        });
      }
    }
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n['read'] = true;
      }
    });
  }

  IconData _getIconData(String type) {
    switch (type) {
      case 'CLASS_REMINDER':
        return Icons.alarm_outlined;
      case 'ROOM_CHANGED':
        return Icons.place_outlined;
      case 'FACULTY_CHANGED':
        return Icons.person_outline;
      case 'CLASS_CANCELLED':
      case 'CLASS_REMOVED':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'CLASS_REMINDER':
        return AppConstants.info;
      case 'ROOM_CHANGED':
        return AppConstants.warning;
      case 'FACULTY_CHANGED':
        return AppConstants.purpleAccent;
      case 'CLASS_CANCELLED':
      case 'CLASS_REMOVED':
        return AppConstants.error;
      default:
        return AppConstants.textSecondary;
    }
  }

  Color _getIconBgColor(String type) {
    switch (type) {
      case 'CLASS_REMINDER':
        return AppConstants.infoContainer.withValues(alpha: 0.5);
      case 'ROOM_CHANGED':
        return AppConstants.warningContainer.withValues(alpha: 0.5);
      case 'FACULTY_CHANGED':
        return AppConstants.purpleContainer.withValues(alpha: 0.5);
      case 'CLASS_CANCELLED':
      case 'CLASS_REMOVED':
        return AppConstants.errorContainer.withValues(alpha: 0.5);
      default:
        return AppConstants.outline;
    }
  }

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return DateFormat('h:mm a').format(dt);
      }
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayNotifications = <Map<String, dynamic>>[];
    final olderNotifications = <Map<String, dynamic>>[];

    for (final n in _notifications) {
      try {
        final dt = DateTime.parse(n['timestamp'] as String).toLocal();
        if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
          todayNotifications.add(n);
        } else {
          olderNotifications.add(n);
        }
      } catch (_) {
        todayNotifications.add(n);
      }
    }

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppConstants.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: AppConstants.getHeadline().copyWith(fontSize: 18),
        ),
        actions: [
          if (_notifications.any((n) => !n['read']))
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: AppConstants.getBodyMedium(color: AppConstants.primary).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
            : _errorMessage != null && _notifications.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppConstants.error, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadNotificationHistory,
                            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _notifications.isNotEmpty
                    ? ListView(
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                        children: [
                          const SizedBox(height: 12),
                          // TODAY section
                          if (todayNotifications.isNotEmpty) ...[
                            Text(
                              'TODAY',
                              style: AppConstants.getLabelSmall().copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: todayNotifications.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) => _buildNotificationRow(todayNotifications[index]),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // OLDER section
                          if (olderNotifications.isNotEmpty) ...[
                            Text(
                              'OLDER',
                              style: AppConstants.getLabelSmall().copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: olderNotifications.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) => _buildNotificationRow(olderNotifications[index]),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Footer divider
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No older notifications',
                                style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.notifications_none, color: AppConstants.textSecondary, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "You're all caught up",
                              style: AppConstants.getHeadline().copyWith(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildNotificationRow(Map<String, dynamic> n) {
    final type = n['type'] as String;
    final isRead = n['read'] as bool;

    final iconData = _getIconData(type);
    final iconColor = _getIconColor(type);
    final iconBg = _getIconBgColor(type);
    final timeText = _formatTimestamp(n['timestamp'] as String);

    return InkWell(
      onTap: () {
        setState(() {
          n['read'] = true;
        });
      },
      borderRadius: BorderRadius.circular(AppConstants.radiusButton),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppConstants.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
          border: Border.all(color: AppConstants.outline),
          boxShadow: AppConstants.shadowLevel1,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        n['title'] as String,
                        style: AppConstants.getHeadline().copyWith(
                          fontSize: 14,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeText,
                        style: AppConstants.getLabelSmall(color: AppConstants.textSecondary).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n['body'] as String,
                    style: AppConstants.getBodyMedium(
                      color: isRead ? AppConstants.textSecondary : AppConstants.textPrimary,
                    ).copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
            // Unread Blue Dot
            if (!isRead)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppConstants.info,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
