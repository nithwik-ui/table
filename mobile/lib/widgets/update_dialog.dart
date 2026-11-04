import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/update/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final String latestTag;
  final String downloadUrl;
  final String? updateMessage;
  final VoidCallback? onUpdateNow;
  final VoidCallback? onLater;

  const UpdateDialog({
    super.key,
    required this.latestTag,
    required this.downloadUrl,
    this.updateMessage,
    this.onUpdateNow,
    this.onLater,
  });

  String get _displayVersion {
    final clean = latestTag.trim();
    if (clean.toLowerCase().startsWith('v')) {
      return clean.substring(1);
    }
    return clean.isEmpty ? '3.1.4' : clean;
  }

  Future<void> _handleUpdate(BuildContext context) async {
    if (onUpdateNow != null) {
      onUpdateNow!();
      return;
    }

    final targetUrl = downloadUrl.isNotEmpty
        ? downloadUrl
        : 'https://play.google.com/store/apps/details?id=com.srutimetable.mobile';

    try {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else {
        throw 'Could not launch $targetUrl';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open update link: $e')),
        );
      }
    }
  }

  void _handleLater(BuildContext context) {
    UpdateService.dismissedThisSession = true;
    if (onLater != null) {
      onLater!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = updateMessage ??
        'SRU Timetable $_displayVersion includes important stability, timetable, dark mode, notification, performance and user experience improvements.';

    return AlertDialog(
      backgroundColor: AppConstants.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        side: BorderSide(color: AppConstants.outline),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Icon(
            Icons.system_update_alt_rounded,
            color: AppConstants.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'New update available',
              style: AppConstants.getHeadline(
                color: AppConstants.textPrimary,
              ).copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SRU Timetable $_displayVersion',
            style: AppConstants.getBodyLarge(
              color: AppConstants.primary,
            ).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppConstants.getBodyMedium(
              color: AppConstants.textSecondary,
            ).copyWith(height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _handleLater(context),
          child: Text(
            'Later',
            style: TextStyle(
              color: AppConstants.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.brandNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusButton),
            ),
            elevation: 0,
          ),
          onPressed: () => _handleUpdate(context),
          child: const Text(
            'Update Now',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
