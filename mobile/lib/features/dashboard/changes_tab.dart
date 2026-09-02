import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import 'ad_banner.dart';
import '../../core/api.dart';
import '../notifications/notifications_screen.dart';

class ChangesTab extends StatefulWidget {
  const ChangesTab({super.key});

  @override
  State<ChangesTab> createState() => _ChangesTabState();
}

class _ChangesTabState extends State<ChangesTab> {
  List<dynamic> _changes = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _fetchChanges();
  }

  void _loadLocalData() {
    if (StorageService.getUserMode() == 'faculty') {
      setState(() {
        _changes = [];
        _isLoading = false;
      });
      return;
    }

    final cached = StorageService.getChangesCache();
    final now = DateTime.now();
    final filtered = cached.where((change) {
      try {
        final dt = DateTime.parse(change['detected_at'] as String).toLocal();
        return now.difference(dt).inDays <= 7;
      } catch (_) {
        return true;
      }
    }).toList();
    
    if (filtered.length != cached.length) {
      StorageService.saveChangesCache(filtered);
    }
    
    setState(() {
      _changes = filtered;
      if (filtered.isNotEmpty) {
        _isLoading = false;
      }
    });
  }

  Future<void> _fetchChanges() async {
    if (StorageService.getUserMode() == 'faculty') {
      setState(() {
        _isLoading = false;
        _isOffline = false;
      });
      return;
    }
  
    final selection = StorageService.getSelection();
    if (selection == null) return;
    final batchId = selection['batchId']!;

    try {
      final list = await ApiService.fetchChanges(batchId);
      await StorageService.saveChangesCache(list);
      if (mounted) {
        setState(() {
          _changes = list;
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }

  Color _getChangeColor(String type) {
    switch (type) {
      case 'CLASS_ADDED':
        return AppConstants.success;
      case 'CLASS_REMOVED':
        return AppConstants.error;
      case 'ROOM_CHANGED':
        return AppConstants.warning;
      case 'FACULTY_CHANGED':
        return AppConstants.purpleAccent;
      default:
        return AppConstants.info;
    }
  }

  Color _getChangeContainerColor(String type) {
    switch (type) {
      case 'CLASS_ADDED':
        return AppConstants.successContainer.withOpacity(0.5);
      case 'CLASS_REMOVED':
        return AppConstants.errorContainer.withOpacity(0.5);
      case 'ROOM_CHANGED':
        return AppConstants.warningContainer.withOpacity(0.5);
      case 'FACULTY_CHANGED':
        return AppConstants.purpleContainer.withOpacity(0.5);
      default:
        return AppConstants.infoContainer.withOpacity(0.5);
    }
  }

  String _getChangeTypeLabel(String type) {
    switch (type) {
      case 'CLASS_ADDED':
        return 'Class Added';
      case 'CLASS_REMOVED':
        return 'Class Cancelled';
      case 'ROOM_CHANGED':
        return 'Room Changed';
      case 'FACULTY_CHANGED':
        return 'Faculty Changed';
      case 'TIME_CHANGED':
        return 'Rescheduled';
      case 'SUBJECT_CHANGED':
        return 'Subject Changed';
      case 'LTP_CHANGED':
        return 'Session Type';
      default:
        return 'Schedule Shift';
    }
  }

  String _formatDetectedTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  Map<String, String>? _getTimetableContext(dynamic change) {
    String subject = 'Class';
    String day = '';
    String time = '';

    final fieldName = change['field_name'] as String? ?? '';
    final fieldParts = fieldName.split(':');
    if (fieldParts.length > 1) {
      final subjectPart = fieldParts.skip(1).join(':');
      // Check if it has our new delimiter format: Subject|Day|Time
      final contextParts = subjectPart.split('|');
      subject = contextParts[0];
      if (contextParts.length == 3) {
        day = contextParts[1];
        time = contextParts[2];
      }
    }

    if (day.isNotEmpty && time.isNotEmpty) {
      return {'day': day, 'time': time, 'subject': subject};
    }
    
    // Fallback for older change records where day/time was not recorded
    final type = change['change_type'] as String? ?? '';
    final newVal = change['new_value'] as String? ?? '';

    final timetable = StorageService.getTimetableCache();
    
    for (final cls in timetable) {
      bool isMatch = cls['subject'] == subject;
      if (isMatch && type == 'FACULTY_CHANGED' && newVal.isNotEmpty) {
        isMatch = cls['faculty'] == newVal;
      } else if (isMatch && type == 'ROOM_CHANGED' && newVal.isNotEmpty) {
        isMatch = cls['room'] == newVal;
      }

      if (isMatch) {
        final startTime = cls['start_time'] as String;
        final endTime = cls['end_time'] as String? ?? '';
        return {
          'day': cls['day'] as String,
          'time': endTime.isNotEmpty ? '$startTime - $endTime' : startTime,
          'subject': subject,
        };
      }
    }
    
    return {'day': day, 'time': time, 'subject': subject};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: AppConstants.textPrimary, size: 24),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Offline banner
            if (_isOffline) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.errorContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    border: Border.all(color: AppConstants.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: AppConstants.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You\'re offline',
                              style: AppConstants.getHeadline().copyWith(fontSize: 14, color: AppConstants.error),
                            ),
                            Text(
                              'Showing last cached timetable changes.',
                              style: AppConstants.getBodyMedium(color: AppConstants.error.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _fetchChanges,
                        child: Text(
                          'Try again',
                          style: AppConstants.getBodyMedium(color: AppConstants.error).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Headline & stats chip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Changes',
                    style: AppConstants.getDisplay().copyWith(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  if (_changes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppConstants.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                      ),
                      child: Text(
                        '${_changes.length} updates this week',
                        style: AppConstants.getLabelSmall(color: AppConstants.onSecondaryContainer).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Content Feed
            if (StorageService.getUserMode() == 'faculty')
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, color: AppConstants.textSecondary, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Not Available',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Changes tracking is only available for student timetables.',
                        style: TextStyle(color: AppConstants.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
                  : _changes.isNotEmpty
                      ? RefreshIndicator(
                          color: AppConstants.primary,
                          onRefresh: _fetchChanges,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                            itemCount: _changes.length,
                            itemBuilder: (context, index) {
                              final change = _changes[index];
                              final type = change['change_type'] as String;
                              
                              final typeLabel = _getChangeTypeLabel(type);
                              final changeColor = _getChangeColor(type);
                              final containerColor = _getChangeContainerColor(type);
                              final timeText = _formatDetectedTime(change['detected_at'] as String);

                              final isCancellation = type == 'CLASS_REMOVED';
                              final isAddition = type == 'CLASS_ADDED';

                              final oldVal = change['old_value'] as String? ?? '';
                              final newVal = change['new_value'] as String? ?? '';
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppConstants.surface,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                    boxShadow: AppConstants.shadowLevel1,
                                    border: Border.all(color: AppConstants.outline),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top meta: Change Tag + timestamp
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: containerColor,
                                              borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                                            ),
                                            child: Text(
                                              typeLabel,
                                              style: AppConstants.getLabelSmall(color: changeColor).copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Text(
                                            timeText,
                                            style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Description values
                                      if (isCancellation) ...[
                                        Text(
                                          oldVal.split('(')[0].trim(),
                                          style: AppConstants.getHeadline().copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Cancelled: $oldVal',
                                          style: AppConstants.getBodyMedium(color: AppConstants.error).copyWith(fontWeight: FontWeight.w500),
                                        ),
                                      ] else if (isAddition) ...[
                                        Text(
                                          newVal.split('(')[0].trim(),
                                          style: AppConstants.getHeadline().copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Added: $newVal',
                                          style: AppConstants.getBodyMedium(color: AppConstants.success).copyWith(fontWeight: FontWeight.w500),
                                        ),
                                      ] else if (type == 'FACULTY_CHANGED') ...[
                                          // Enhanced Faculty Change UI
                                          Builder(
                                            builder: (context) {
                                              final contextData = _getTimetableContext(change) ?? {};
                                              final subject = contextData['subject'] ?? 'Class';
                                              final day = contextData['day'] ?? '';
                                              final time = contextData['time'] ?? '';
                                              
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    subject,
                                                    style: AppConstants.getHeadline().copyWith(fontSize: 16),
                                                  ),
                                                  if (day.isNotEmpty || time.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${day.isNotEmpty ? day : ''}${day.isNotEmpty && time.isNotEmpty ? ' • ' : ''}${time.isNotEmpty ? time : ''}',
                                                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 10),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants.background,
                                                      borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          oldVal,
                                                          style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(
                                                            decoration: TextDecoration.lineThrough,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                        const Padding(
                                                          padding: EdgeInsets.symmetric(vertical: 4),
                                                          child: Icon(Icons.arrow_downward, size: 16, color: AppConstants.textSecondary),
                                                        ),
                                                        Text(
                                                          newVal,
                                                          style: AppConstants.getHeadline(color: AppConstants.primary).copyWith(fontSize: 14),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ] else ...[
                                        // Mod
                                        // We don't have entry details linked directly, but we can print what changed:
                                        Text(
                                          change['field_name'] == 'subject' ? 'Subject Update' : 'Schedule Modification',
                                          style: AppConstants.getHeadline().copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 10),
                                        // Diff layout old -> new
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppConstants.background,
                                            borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  oldVal,
                                                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8),
                                                child: Icon(Icons.arrow_forward, size: 16, color: AppConstants.textSecondary),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  newVal,
                                                  style: AppConstants.getHeadline(color: AppConstants.primary).copyWith(fontSize: 14),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppConstants.success, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'You\'re all caught up',
                                style: AppConstants.getHeadline().copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No recent changes found for your timetable.',
                                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                              ),
                            ],
                          ),
                        ),
            ),
            const AdBanner(),
          ],
        ),
      ),
    );
  }
}
