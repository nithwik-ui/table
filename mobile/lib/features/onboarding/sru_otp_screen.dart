import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/sync.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/sru/sru_auth_client.dart';
import '../../core/sms_retriever_service.dart';
import '../../core/timetable/timetable_repository.dart';
import '../dashboard/dashboard_screen.dart';

class SruOtpScreen extends StatefulWidget {
  const SruOtpScreen({super.key});

  @override
  State<SruOtpScreen> createState() => _SruOtpScreenState();
}

class _SruOtpScreenState extends State<SruOtpScreen> with CodeAutoFill {
  final TextEditingController _otpController = TextEditingController();
  late final SmartAuthUserConsentRetriever _smsRetriever;
  bool _isLoading = false;
  String _loadingMessage = 'Verifying...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _smsRetriever = const SmartAuthUserConsentRetriever();
    // Prefetch CSRF token in background so verify is instant
    SruAuthClient.instance.prefetchOtpToken();
    try {
      listenForCode();
    } catch (_) {}
  }

  @override
  void codeUpdated() {
    if (code != null && code!.isNotEmpty) {
      final match = RegExp(r'\b\d{6}\b').firstMatch(code!);
      final digits = match != null ? match.group(0)! : code!;
      setState(() {
        _otpController.text = digits;
      });
      if (_otpController.text.length == 6) {
        _verifyOtp();
      }
    }
  }

  @override
  void dispose() {
    try {
      cancel();
    } catch (_) {}
    _smsRetriever.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() async {
    final otpText = _otpController.text.trim();
    if (otpText.length < 6) return;
    
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Verifying code...';
      _errorMessage = null;
    });

    try {
      await AuthRepository.instance.verifyOtp(otpText);
      final role = AuthRepository.instance.currentRole ?? 'student';
      final id = AuthRepository.instance.savedIdentifier;
      await StorageService.setUserMode(role);
      if (id != null && id.isNotEmpty) {
        await StorageService.saveUserIdentifier(id);
        if (RegExp(r'\b2[0-9][0-9A-Za-z]{2}[A-Za-z0-9]{6}\b').hasMatch(id)) {
          await StorageService.saveStudentRollNumber(id);
        }
      }
      
      if (mounted) {
        setState(() {
          _loadingMessage = 'Loading your timetable...';
        });
      }
      
      // Await initial timetable sync so the user lands on the dashboard with full timetable ready
      try {
        await SyncService.instance.syncTimetable(force: true).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('[OTP] Initial timetable sync caught non-fatal: $e');
      }

      TimetableRepository.instance.loadFromCache();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 0)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final msg = e.toString();
          if (msg.contains('TimeoutException')) {
            _errorMessage = 'Verification request timed out. Please check your connection and try again.';
          } else if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
            _errorMessage = 'Unable to connect to SRU portal. Please check your internet connection.';
          } else if (e is SruAuthException) {
            _errorMessage = e.message;
          } else {
            _errorMessage = msg.replaceAll(RegExp(r'^(Exception|Error|SruAuthException):\s*'), '');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: AppConstants.getHeadline().copyWith(fontSize: 20),
      decoration: BoxDecoration(
        border: Border.all(color: AppConstants.outline),
        borderRadius: BorderRadius.circular(12),
        color: AppConstants.surface,
      ),
    );

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: Text('Verification', style: AppConstants.getHeadline()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Verify your account',
                style: AppConstants.getHeadline().copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the OTP sent to your registered mobile number or SRU email.',
                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppConstants.errorContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppConstants.getBodyMedium(color: AppConstants.error),
                  ),
                ),
              Center(
                child: Pinput(
                  length: 6,
                  controller: _otpController,
                  defaultPinTheme: defaultPinTheme,
                  keyboardType: TextInputType.number,
                  smsRetriever: _smsRetriever,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(color: AppConstants.primary, width: 2),
                  ),
                  onCompleted: (v) => _verifyOtp(),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primary,
                  foregroundColor: AppConstants.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Text(_loadingMessage, style: const TextStyle(color: Colors.white)),
                        ],
                      )
                    : const Text('Verify'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
