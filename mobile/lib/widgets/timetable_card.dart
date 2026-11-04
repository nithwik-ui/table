import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../core/timetable_status_engine.dart';
import '../features/dashboard/widgets/live_class_progress.dart';
import 'class_details_bottom_sheet.dart';

/// A robust, responsive timetable class card widget that guarantees
/// no visual collisions or overlaps between subjects, time/room metadata,
/// faculty, and status/type badges across all device widths, text scales, and themes.
class TimetableCard extends StatelessWidget {
  final Map<String, dynamic> classEvent;
  final String? status;
  final String? dateStr;
  final bool isToday;
  final DateTime? referenceDate;
  final DateTime? nowLocal;
  final bool isFeatured;
  final String? countdownText;
  final VoidCallback? onTap;

  const TimetableCard({
    super.key,
    required this.classEvent,
    this.status,
    this.dateStr,
    this.isToday = true,
    this.referenceDate,
    this.nowLocal,
    this.isFeatured = false,
    this.countdownText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = classEvent;
    final subject = c['subject'] as String? ?? 'No Subject';
    final startTime = c['start_time'] as String? ?? '00:00';
    final endTime = c['end_time'] as String? ?? '00:00';
    final formattedStartTime = TimeUtils.format12Hour(startTime);
    final formattedEndTime = TimeUtils.format12Hour(endTime);
    final formattedTime = '$formattedStartTime – $formattedEndTime';

    final rawRoom = c['room'] as String? ?? 'No Room';
    final room = rawRoom.split('_')[0].trim();

    final rawFaculty = c['faculty'] as String? ?? '';
    final faculty = rawFaculty.trim();

    final ltp = (c['ltp'] as String? ?? '').trim();
    final isLab = ltp.toLowerCase().contains('lab') ||
        ltp.toLowerCase().contains('practical') ||
        ltp.toUpperCase() == 'P';
    final isLecture =
        ltp.toLowerCase().contains('lecture') || ltp.toUpperCase() == 'L';
    final isTutorial =
        ltp.toLowerCase().contains('tutorial') || ltp.toUpperCase() == 'T';

    final isCancelled = c['isCancelled'] == true ||
        c['is_cancelled'] == true ||
        (status != null && status!.toLowerCase() == 'cancelled');
    final isChanged = c['isChanged'] == true ||
        c['is_changed'] == true ||
        c['change_type'] != null;

    // Determine canonical status using class calendar date + current IST time
    final sruNow = nowLocal ?? TimeUtils.nowInSruTime();
    final effectiveClassDate = referenceDate ?? sruNow;
    final classStatus = TimetableStatusEngine.getStatus(
      classData: c,
      referenceDate: effectiveClassDate,
      nowLocal: sruNow,
    );

    final bool isCompleted = classStatus == ClassStatus.completed;
    final bool isOngoing = classStatus == ClassStatus.ongoing;

    String statusText;
    Color statusColor;
    Color statusBg;
    IconData? statusIcon;

    if (isCancelled) {
      statusText = 'Cancelled';
      statusColor = AppConstants.cancelledText;
      statusBg = AppConstants.cancelledBg;
      statusIcon = Icons.cancel_outlined;
    } else if (status != null && status!.isNotEmpty) {
      statusText = status!;
      if (statusText == 'Ongoing' || statusText.startsWith('Ongoing')) {
        statusColor = AppConstants.ongoingText;
        statusBg = AppConstants.ongoingBg;
        statusIcon = Icons.fiber_manual_record;
      } else if (statusText == 'Completed') {
        statusText = 'Completed';
        statusColor = AppConstants.completedText;
        statusBg = AppConstants.completedBg;
        statusIcon = Icons.check_circle_outline_rounded;
      } else if (statusText == 'Cancelled') {
        statusColor = AppConstants.cancelledText;
        statusBg = AppConstants.cancelledBg;
        statusIcon = Icons.cancel_outlined;
      } else if (statusText == 'Changed') {
        statusColor = AppConstants.warningText;
        statusBg = AppConstants.warningContainer;
        statusIcon = Icons.edit_calendar_outlined;
      } else {
        statusColor = AppConstants.upcomingText;
        statusBg = AppConstants.upcomingBg;
        statusIcon = Icons.schedule_rounded;
      }
    } else if (isOngoing) {
      statusText = 'Ongoing';
      statusColor = AppConstants.ongoingText;
      statusBg = AppConstants.ongoingBg;
      statusIcon = Icons.fiber_manual_record;
    } else if (isCompleted) {
      statusText = 'Completed';
      statusColor = AppConstants.completedText;
      statusBg = AppConstants.completedBg;
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (isChanged) {
      statusText = 'Changed';
      statusColor = AppConstants.warningText;
      statusBg = AppConstants.warningContainer;
      statusIcon = Icons.edit_calendar_outlined;
    } else {
      statusText = 'Upcoming';
      statusColor = AppConstants.upcomingText;
      statusBg = AppConstants.upcomingBg;
      statusIcon = Icons.schedule_rounded;
    }

    // Countdown badge for featured/ongoing/up-next cards on today
    String? countdownLabel = countdownText;
    if (countdownLabel == null && !isCancelled && isToday) {
      if (isOngoing) {
        countdownLabel = TimetableStatusEngine.getCountdownText(
          classData: c,
          referenceDate: effectiveClassDate,
          nowLocal: sruNow,
        );
      } else if (isFeatured && classStatus == ClassStatus.upcoming) {
        final cd = TimetableStatusEngine.getCountdownText(
          classData: c,
          referenceDate: effectiveClassDate,
          nowLocal: sruNow,
        );
        if (cd != statusText) {
          countdownLabel = cd;
        }
      }
    }

    // Guard against duplicate countdown chips (e.g. status badge already showing "Starts in 43 min")
    if (countdownLabel != null) {
      final normLabel = countdownLabel.trim().toLowerCase();
      final normStatus = statusText.trim().toLowerCase();
      if (normLabel == normStatus ||
          normStatus.contains(normLabel) ||
          normLabel.contains(normStatus) ||
          normStatus.startsWith('starts in') ||
          normStatus.startsWith('ends in')) {
        countdownLabel = null;
      }
    }

    // Left accent indicator based on class type and status
    final Color accentColor;
    if (isCancelled) {
      accentColor = AppConstants.cancelledAccent;
    } else if (statusText == 'Ongoing' || isOngoing) {
      accentColor = AppConstants.ongoingAccent;
    } else if (isLab) {
      accentColor = AppConstants.labAccent;
    } else if (isTutorial) {
      accentColor = AppConstants.tutorialAccent;
    } else if (ltp.toLowerCase().contains('practical')) {
      accentColor = AppConstants.practicalAccent;
    } else if (ltp.toLowerCase().contains('exam') ||
        ltp.toLowerCase().contains('test')) {
      accentColor = AppConstants.examAccent;
    } else if (statusText == 'Completed' || isCompleted) {
      accentColor = AppConstants.completedAccent.withValues(alpha: 0.7);
    } else {
      accentColor = AppConstants.lectureAccent;
    }

    // Type badge label & semantic color pair
    String? typeBadge;
    Color typeBg = AppConstants.lectureBg;
    Color typeColor = AppConstants.lectureText;

    if (isLab) {
      typeBadge = 'Lab';
      typeBg = AppConstants.labBg;
      typeColor = AppConstants.labText;
    } else if (isLecture) {
      typeBadge = 'Lecture';
      typeBg = AppConstants.lectureBg;
      typeColor = AppConstants.lectureText;
    } else if (isTutorial) {
      typeBadge = 'Tutorial';
      typeBg = AppConstants.tutorialBg;
      typeColor = AppConstants.tutorialText;
    } else if (ltp.isNotEmpty && ltp.length <= 12) {
      typeBadge = ltp;
      typeBg = AppConstants.practicalBg;
      typeColor = AppConstants.practicalText;
    }

    final bool isHighlighted = (statusText == 'Ongoing' || isOngoing);

    return Container(
      decoration: BoxDecoration(
        color: isCancelled
            ? AppConstants.surface.withValues(alpha: 0.65)
            : (isHighlighted
                ? (AppConstants.isDark
                    ? AppConstants.surfaceElevated
                    : const Color(0xFFFBFDFF))
                : AppConstants.surface),
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        boxShadow: isCancelled
            ? null
            : (isFeatured || isHighlighted
                ? AppConstants.shadowLevel2
                : AppConstants.shadowLevel1),
        border: isCancelled
            ? Border.all(
                color: AppConstants.outline.withValues(alpha: 0.7),
                width: 1.0,
              )
            : (isHighlighted
                ? Border.all(
                    color: AppConstants.primary.withValues(alpha: 0.45),
                    width: 1.5,
                  )
                : (isFeatured
                    ? Border.all(
                        color: AppConstants.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      )
                    : Border.all(color: AppConstants.outline, width: 1.0))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          onTap: onTap ??
              () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => ClassDetailsBottomSheet(
                    classEvent: c,
                    status: statusText,
                    dateStr: dateStr ??
                        DateFormat('EEEE, d MMMM')
                            .format(TimeUtils.getKolkataTime()),
                  ),
                );
              },
          child: Stack(
            children: [
              // Left Accent Pill Indicator
              Positioned(
                left: 14,
                top: 14,
                bottom: 14,
                width: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                  ),
                ),
              ),

              // Main Content Container
              Padding(
                padding: EdgeInsets.fromLTRB(
                  28.0,
                  isFeatured ? 18.0 : 15.0,
                  isFeatured ? 18.0 : 15.0,
                  isFeatured ? 18.0 : 15.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Subject Section
                    Text(
                      subject,
                      style: AppConstants.getHeadline().copyWith(
                        fontSize: isFeatured ? 17 : 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        decoration:
                            isCancelled ? TextDecoration.lineThrough : null,
                        color: isCancelled
                            ? AppConstants.textMuted
                            : AppConstants.textPrimary,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),

                    // 2. Time & Location Metadata
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxItemWidth = constraints.maxWidth;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Time item
                            ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxWidth: maxItemWidth),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 15,
                                    color: isCancelled
                                        ? AppConstants.error
                                        : AppConstants.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      formattedTime,
                                      style: AppConstants.getBodyMedium(
                                        color: isCancelled
                                            ? AppConstants.error
                                            : AppConstants.textPrimary,
                                      ).copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                        decoration: isCancelled
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      softWrap: true,
                                    ),
                                  ),
                                  if (!isCancelled &&
                                      (statusText == 'Ongoing' ||
                                          isOngoing)) ...[
                                    const SizedBox(width: 8),
                                    LiveClassProgressIndicator(
                                      startTime: startTime,
                                      endTime: endTime,
                                      isToday: isToday,
                                      referenceDate: effectiveClassDate,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Room item
                            ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxWidth: maxItemWidth),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 15,
                                    color: isCancelled
                                        ? AppConstants.error
                                        : AppConstants.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      room.isNotEmpty ? room : 'TBA',
                                      style: AppConstants.getBodyMedium(
                                        color: isCancelled
                                            ? AppConstants.error
                                            : AppConstants.textSecondary,
                                      ).copyWith(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                        decoration: isCancelled
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // 3. Faculty Metadata
                    if (faculty.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 15,
                            color: AppConstants.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              faculty,
                              style: AppConstants.getBodyMedium(
                                color: isCancelled
                                    ? AppConstants.textMuted
                                    : AppConstants.textPrimary,
                              ).copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // 4. Dedicated Bottom / Status Row
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Status Badge (with accessible icon + text)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 260),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusTag),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                size: statusIcon == Icons.fiber_manual_record
                                    ? 8
                                    : 12,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                statusText,
                                style: AppConstants.getLabelSmall(
                                  color: statusColor,
                                ).copyWith(fontWeight: FontWeight.w700),
                                softWrap: true,
                              ),
                            ),
                            ],
                          ),
                        ),

                        // Countdown Badge (e.g., "Ends in 32 min" or "Starts in 18 min")
                        if (countdownLabel != null &&
                            countdownLabel.isNotEmpty)
                          Container(
                          constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppConstants.infoContainer,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusTag),
                              border: Border.all(
                                color: AppConstants.infoText
                                    .withValues(alpha: 0.22),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 12,
                                  color: AppConstants.infoText,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                child: Text(
                                  countdownLabel,
                                  style: AppConstants.getLabelSmall(
                                    color: AppConstants.infoText,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                  softWrap: true,
                                ),
                              ),
                              ],
                            ),
                          ),

                        // Type Badge (Lab / Lecture / Tutorial)
                        if (typeBadge != null && !isCancelled)
                          Container(
                          constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: typeBg,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusTag),
                              border: Border.all(
                                color: typeColor.withValues(alpha: 0.22),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              typeBadge,
                              style: AppConstants.getLabelSmall(
                                color: typeColor,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),

                        // Changed Badge
                        if (isChanged &&
                            statusText != 'Changed' &&
                            !isCancelled)
                          Container(
                          constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppConstants.warningContainer,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusTag),
                              border: Border.all(
                                color: AppConstants.warningText
                                    .withValues(alpha: 0.22),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_calendar_outlined,
                                    size: 12, color: AppConstants.warningText),
                                const SizedBox(width: 4),
                                Flexible(
                                child: Text(
                                  'Changed',
                                  style: AppConstants.getLabelSmall(
                                    color: AppConstants.warningText,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                  softWrap: true,
                                ),
                              ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
