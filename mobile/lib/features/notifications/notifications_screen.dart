import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Mock notification data since push notifications (FCM) is Phase 7
  // We populate mock items so the UI is fully complete and testable
  final List<Map<String, dynamic>> _mockNotifications = [
    {
      'id': '1',
      'title': 'Room Changed',
      'body': 'Algorithms (CS-301) moved to 1202-BL1-SF.',
      'type': 'ROOM_CHANGED',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
      'read': false,
    },
    {
      'id': '2',
      'title': 'Class Cancelled',
      'body': 'Software Engineering and System Design (CS-303) has been cancelled for today.',
      'type': 'CLASS_CANCELLED',
      'timestamp': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'read': false,
    },
    {
      'id': '3',
      'title': 'Faculty Changed',
      'body': 'Statistics for Computer Science will be taken by Dr. Kiran Kumar Thula today.',
      'type': 'FACULTY_CHANGED',
      'timestamp': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      'read': true,
    },
    {
      'id': '4',
      'title': 'Class Reminder',
      'body': 'Algorithms starting in 15 mins (1106-B_BL1-FF).',
      'type': 'CLASS_REMINDER',
      'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 2)).toIso8601String(),
      'read': true,
    },
  ];

  void _markAllRead() {
    setState(() {
      for (final n in _mockNotifications) {
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
        return AppConstants.error;
      default:
        return AppConstants.textSecondary;
    }
  }

  Color _getIconBgColor(String type) {
    switch (type) {
      case 'CLASS_REMINDER':
        return AppConstants.infoContainer.withOpacity(0.5);
      case 'ROOM_CHANGED':
        return AppConstants.warningContainer.withOpacity(0.5);
      case 'FACULTY_CHANGED':
        return AppConstants.purpleContainer.withOpacity(0.5);
      case 'CLASS_CANCELLED':
        return AppConstants.errorContainer.withOpacity(0.5);
      default:
        return AppConstants.outline;
    }
  }

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate today vs yesterday
    final now = DateTime.now();
    final todayNotifications = <Map<String, dynamic>>[];
    final yesterdayNotifications = <Map<String, dynamic>>[];

    for (final n in _mockNotifications) {
      try {
        final dt = DateTime.parse(n['timestamp'] as String);
        if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
          todayNotifications.add(n);
        } else {
          yesterdayNotifications.add(n);
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
          if (_mockNotifications.any((n) => !n['read']))
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
        child: _mockNotifications.isNotEmpty
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

                  // YESTERDAY section
                  if (yesterdayNotifications.isNotEmpty) ...[
                    Text(
                      'YESTERDAY',
                      style: AppConstants.getLabelSmall().copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: yesterdayNotifications.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildNotificationRow(yesterdayNotifications[index]),
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
