import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/utils.dart';

class LiveFreeSlotProgressIndicator extends StatefulWidget {
  final String startTime;
  final String endTime;
  final bool isToday;

  const LiveFreeSlotProgressIndicator({
    super.key,
    required this.startTime,
    required this.endTime,
    this.isToday = true,
  });

  @override
  State<LiveFreeSlotProgressIndicator> createState() => _LiveFreeSlotProgressIndicatorState();
}

class _LiveFreeSlotProgressIndicatorState extends State<LiveFreeSlotProgressIndicator> {
  Timer? _timer;
  double _progress = 0.0;
  int _remainingMins = 0;

  @override
  void initState() {
    super.initState();
    _updateProgress();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _updateProgress());
  }

  @override
  void didUpdateWidget(LiveFreeSlotProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime || oldWidget.endTime != widget.endTime) {
      _updateProgress();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateProgress() {
    if (!mounted || !widget.isToday) return;

    final now = DateTime.now();
    try {
      final startParts = widget.startTime.split(':');
      final endParts = widget.endTime.split(':');
      
      if (startParts.length != 2 || endParts.length != 2) return;

      final startDt = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
      final endDt = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));

      if (now.compareTo(startDt) >= 0 && now.isBefore(endDt)) {
        final totalMins = endDt.difference(startDt).inMinutes;
        final elapsedMins = now.difference(startDt).inMinutes;
        final remaining = endDt.difference(now).inMinutes;
        
        if (totalMins > 0) {
          final p = (elapsedMins / totalMins).clamp(0.0, 1.0);
          setState(() {
            _progress = p;
            _remainingMins = remaining;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = _progress > 0 && _progress < 1 ? 'Free Time' : 'Free Time';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(color: AppConstants.secondaryContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.coffee, size: 18, color: AppConstants.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: AppConstants.getHeadline().copyWith(fontSize: 15, color: AppConstants.primary),
                  ),
                ],
              ),
              Text(
                '${TimeUtils.format12Hour(widget.startTime)} - ${TimeUtils.format12Hour(widget.endTime)}',
                style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
              ),
            ],
          ),
          if (widget.isToday) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: AppConstants.outline,
                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_remainingMins min remaining',
              style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
