import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import 'academic_login_screen.dart';
import 'academic_dashboard.dart';

/// The Academic tab for Student Mode.
/// Shows either the "Connect SRAAP" first-time state or the Academic Dashboard.
class AcademicTab extends StatefulWidget {
  const AcademicTab({super.key});

  @override
  State<AcademicTab> createState() => _AcademicTabState();
}

class _AcademicTabState extends State<AcademicTab> {
  @override
  Widget build(BuildContext context) {
    final isConnected = StorageService.isSraapConnected();

    if (isConnected) {
      return const AcademicDashboard();
    } else {
      return _AcademicConnectState(
        onConnected: () => setState(() {}),
      );
    }
  }
}

/// First-time state: shown when SRAAP is not yet connected.
class _AcademicConnectState extends StatelessWidget {
  final VoidCallback onConnected;
  const _AcademicConnectState({required this.onConnected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 24),
          children: [
            const SizedBox(height: 32),
            // Icon
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppConstants.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: AppConstants.primary,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Your Academic Space',
              textAlign: TextAlign.center,
              style: AppConstants.getDisplay().copyWith(fontSize: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your SRAAP account to access your academic information.',
              textAlign: TextAlign.center,
              style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay connected while your SRAAP session is valid.',
              textAlign: TextAlign.center,
              style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 36),

            // Benefits
            _BenefitRow(icon: Icons.fact_check_outlined, label: 'Attendance'),
            _BenefitRow(icon: Icons.bar_chart_outlined, label: 'CGPA / SGPA'),
            _BenefitRow(icon: Icons.assignment_outlined, label: 'Results'),
            _BenefitRow(icon: Icons.warning_amber_outlined, label: 'Backlogs'),
            _BenefitRow(icon: Icons.book_outlined, label: 'Subjects'),
            _BenefitRow(icon: Icons.person_outlined, label: 'Mentor'),

            const SizedBox(height: 40),

            // CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
                  ).then((success) {
                    if (success == true) {
                      onConnected();
                    }
                  });
                },
                child: Text(
                  'Connect SRAAP',
                  style: AppConstants.getBodyLarge(color: Colors.white).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppConstants.successContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppConstants.success, size: 18),
          ),
          const SizedBox(width: 14),
          Text(label, style: AppConstants.getBodyLarge()),
        ],
      ),
    );
  }
}
