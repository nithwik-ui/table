import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/sync.dart';
import '../../core/timetable/timetable_repository.dart';

enum ChangesViewState { loading, success, empty, error, timeout }

class ChangesTab extends StatefulWidget {
  const ChangesTab({super.key});

  @override
  State<ChangesTab> createState() => _ChangesTabState();
}

class _ChangesTabState extends State<ChangesTab> {
  List<dynamic> _changes = [];
  ChangesViewState _viewState = ChangesViewState.loading;
  String? _errorMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    SyncService.instance.addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted) {
      _loadLocalData();
    }
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncUpdate);
    super.dispose();
  }

  void _loadLocalData() {
    final isFaculty = StorageService.getUserMode() == 'faculty';
    final cached = isFaculty ? StorageService.getFacultyChangesCache() : StorageService.getChangesCache();
    
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
      if (isFaculty) {
        StorageService.saveFacultyChangesCache(filtered);
      } else {
        StorageService.saveChangesCache(filtered);
      }
    }
    
    if (mounted) {
      setState(() {
        _changes = filtered;
        _isOffline = false;
        _viewState = filtered.isNotEmpty ? ChangesViewState.success : ChangesViewState.empty;
      });
    }
  }

  Future<void> _fetchChanges() async {
    if (!mounted) return;
    setState(() {
      if (_changes.isEmpty) {
        _viewState = ChangesViewState.loading;
      }
      _errorMessage = null;
    });

    try {
      // Bounded timeout: maximum 8 seconds
      await SyncService.instance.syncTimetable(force: true).timeout(const Duration(seconds: 8));
      _loadLocalData();
    } on TimeoutException {
      if (mounted) {
        setState(() {
          if (_changes.isEmpty) {
            _viewState = ChangesViewState.timeout;
            _errorMessage = 'Sync timed out. Please try again.';
          } else {
            _isOffline = true;
          }
        });
      }
    } catch (e) {
      debugPrint('[CHANGES] Fetch changes non-fatal: $e');
      if (mounted) {
        setState(() {
          if (_changes.isEmpty) {
            _viewState = ChangesViewState.error;
            _errorMessage = "Couldn't refresh changes. Check connection and try again.";
          } else {
            _isOffline = true;
          }
        });
      }
    } finally {
      if (mounted && _viewState == ChangesViewState.loading) {
        setState(() {
          _viewState = _changes.isNotEmpty ? ChangesViewState.success : ChangesViewState.empty;
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
        return AppConstants.successContainer.withValues(alpha: 0.5);
      case 'CLASS_REMOVED':
        return AppConstants.errorContainer.withValues(alpha: 0.5);
      case 'ROOM_CHANGED':
        return AppConstants.warningContainer.withValues(alpha: 0.5);
      case 'FACULTY_CHANGED':
        return AppConstants.purpleContainer.withValues(alpha: 0.5);
      default:
        return AppConstants.infoContainer.withValues(alpha: 0.5);
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

    final isFaculty = StorageService.getUserMode() == 'faculty';
    final timetable = TimetableRepository.instance.classes.isNotEmpty
        ? TimetableRepository.instance.classes
        : (isFaculty ? StorageService.getFacultyTimetableCache() : StorageService.getTimetableCache());
    
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
    return ColoredBox(
      color: AppConstants.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // (Header is now in SruAppBar / ChangesScreen AppBar)
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
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppConstants.paddingContainer, 16, AppConstants.paddingContainer, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Changes',
                      style: AppConstants.getDisplay().copyWith(fontSize: 28),
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
            ),
            const SizedBox(height: 8),

            // Content Feed
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      );
    }

  Widget _buildContent() {
    switch (_viewState) {
      case ChangesViewState.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppConstants.primary),
        );
      case ChangesViewState.timeout:
      case ChangesViewState.error:
        if (_changes.isNotEmpty) {
          return _buildChangesList();
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _viewState == ChangesViewState.timeout ? Icons.timer_off_outlined : Icons.cloud_off_outlined,
                  color: AppConstants.textSecondary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _viewState == ChangesViewState.timeout ? 'Request Timed Out' : 'Unable to Load Changes',
                  style: AppConstants.getHeadline().copyWith(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage ?? 'Something went wrong while fetching changes.',
                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _fetchChanges,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        );
      case ChangesViewState.empty:
        return RefreshIndicator(
          color: AppConstants.primary,
          onRefresh: _fetchChanges,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              Center(
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
            ],
          ),
        );
      case ChangesViewState.success:
        return _buildChangesList();
    }
  }

  Widget _buildChangesList() {
    return RefreshIndicator(
      color: AppConstants.primary,
      onRefresh: _fetchChanges,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: AppConstants.paddingContainer,
          right: AppConstants.paddingContainer,
          bottom: 20,
        ),
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
                  ] else if (type == 'FACULTY_CHANGED' || type == 'ROOM_CHANGED') ...[
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
    );
  }
}

/// A routable screen that wraps [ChangesTab] with a back button so it can be
/// pushed from the top-right app bar. All existing Changes logic is unchanged.
class ChangesScreen extends StatelessWidget {
  const ChangesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: AppConstants.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppConstants.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Changes', style: AppConstants.getHeadline().copyWith(fontSize: 18)),
      ),
      body: const ChangesTab(),
    );
  }
}
