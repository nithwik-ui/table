import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import 'degree_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();

  void _onContinue() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await StorageService.saveUserName(name);
    } else {
      await StorageService.saveUserName(null);
    }
    _navigateToDegree();
  }

  void _onSkip() async {
    await StorageService.saveUserName(null);
    _navigateToDegree();
  }

  void _navigateToDegree() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DegreeScreen()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Mini Header
              Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              const Spacer(flex: 2),
              // Body Welcome Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppConstants.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                  boxShadow: AppConstants.shadowLevel1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'What should we call you?',
                      style: AppConstants.getHeadline().copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ll use this to greet you — nothing else.',
                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      style: AppConstants.getBodyLarge(),
                      decoration: InputDecoration(
                        hintText: 'First name',
                        hintStyle: AppConstants.getBodyLarge(color: AppConstants.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                          borderSide: const BorderSide(color: AppConstants.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                          borderSide: const BorderSide(color: AppConstants.primary, width: 1.5),
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 24),
                    // Continue button (no arrow as per spec visual distinction)
                    ElevatedButton(
                      onPressed: _onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primary,
                        foregroundColor: AppConstants.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: AppConstants.getBodyLarge(color: AppConstants.onPrimary).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Skip button
                    TextButton(
                      onPressed: _onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppConstants.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        'Skip for now',
                        style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
