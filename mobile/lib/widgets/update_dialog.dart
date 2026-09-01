import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

class UpdateDialog extends StatelessWidget {
  final String latestTag;
  final String downloadUrl;

  const UpdateDialog({
    super.key,
    required this.latestTag,
    required this.downloadUrl,
  });

  Future<void> _launchUrl(BuildContext context) async {
    // Redirect all users to the Play Store page for SRU Timetable
    final playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=com.srutimetable.mobile');
    try {
      if (await canLaunchUrl(playStoreUrl)) {
        await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else {
        throw 'Could not launch Play Store';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open Play Store: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Available'),
      content: Text('A new version of SRU Timetable ($latestTag) is available. Please update to continue using the latest features.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later', style: TextStyle(color: AppConstants.textSecondary)),
        ),
        TextButton(
          onPressed: () => _launchUrl(context),
          child: const Text('Download Update', style: TextStyle(color: AppConstants.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
