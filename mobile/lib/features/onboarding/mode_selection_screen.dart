import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import 'sru_login_screen.dart';


class ModeSelectionScreen extends StatelessWidget {
  final bool isSwitching;

  const ModeSelectionScreen({super.key, this.isSwitching = false});

  void _selectStudent(BuildContext context) async {
    await StorageService.setUserMode('student');
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SruLoginScreen(role: 'student')),
      );
    }
  }

  void _selectFaculty(BuildContext context) async {
    await StorageService.setUserMode('faculty');
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SruLoginScreen(role: 'faculty')),
      );
    }
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppConstants.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          boxShadow: AppConstants.shadowLevel1,
          border: Border.all(color: AppConstants.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppConstants.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppConstants.getHeadline().copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppConstants.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: isSwitching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isSwitching) const SizedBox(height: 24),
              if (!isSwitching)
                Row(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              const Spacer(flex: 1),
              Text(
                'Welcome to SRU Timetable',
                style: AppConstants.getHeadline().copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you use SRU Timetable',
                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildCard(
                context: context,
                title: 'Student',
                subtitle: 'View your classes, attendance and timetable',
                icon: Icons.school,
                onTap: () => _selectStudent(context),
              ),
              const SizedBox(height: 16),
              _buildCard(
                context: context,
                title: 'Faculty',
                subtitle: 'View your teaching schedule and timetable',
                icon: Icons.person,
                onTap: () => _selectFaculty(context),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
