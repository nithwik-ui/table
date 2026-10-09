import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/utils.dart';

class LiveClassProgressIndicator extends StatefulWidget {
  final String startTime;
  final String endTime;
  final bool isToday;

  const LiveClassProgressIndicator({
    super.key,
    required this.startTime,
    required this.endTime,
    this.isToday = true,
  });

  @override
  State<LiveClassProgressIndicator> createState() => _LiveClassProgressIndicatorState();
}

class _LiveClassProgressIndicatorState extends State<LiveClassProgressIndicator> {
  Timer? _timer;
  double _progress = 0.0;
  bool _isOngoing = false;

  @override
  void initState() {
    super.initState();
    _updateProgress();
    if (widget.isToday) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateProgress());
    }
  }

  @override
  void didUpdateWidget(LiveClassProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime ||
        oldWidget.endTime != widget.endTime ||
        oldWidget.isToday != widget.isToday) {
      _timer?.cancel();
      _updateProgress();
      if (widget.isToday) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateProgress());
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateProgress() {
    if (!widget.isToday || !mounted) {
      if (_isOngoing || _progress != 0.0) {
        setState(() {
          _isOngoing = false;
          _progress = 0.0;
        });
      }
      return;
    }

    final now = TimeUtils.getKolkataTime();
    try {
      final startParts = widget.startTime.split(':');
      final endParts = widget.endTime.split(':');
      
      if (startParts.length != 2 || endParts.length != 2) return;

      final startDt = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
      final endDt = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));

      // Class is ongoing if now is equal to or after startDt AND before endDt.
      // E.g. class 9:30 - 11:00. At 9:30 it's ongoing (0%). At 11:00 it's no longer ongoing.
      if (now.compareTo(startDt) >= 0 && now.isBefore(endDt)) {
        final totalSecs = endDt.difference(startDt).inSeconds;
        final elapsedSecs = now.difference(startDt).inSeconds;
        
        if (totalSecs > 0) {
          final p = (elapsedSecs / totalSecs).clamp(0.0, 1.0);
          if (!_isOngoing || _progress != p) {
            setState(() {
              _isOngoing = true;
              _progress = p;
            });
          }
        }
      } else {
        if (_isOngoing || _progress != 0.0) {
          setState(() {
            _isOngoing = false;
            _progress = 0.0;
          });
        }
      }
    } catch (_) {
      if (_isOngoing || _progress != 0.0) {
        setState(() {
          _isOngoing = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOngoing) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        value: _progress,
        strokeWidth: 3,
        color: AppConstants.primary,
        backgroundColor: AppConstants.outline,
      ),
    );
  }
}
