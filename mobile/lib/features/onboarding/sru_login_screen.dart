import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/sync.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_state.dart';
import '../../core/sru/sru_auth_client.dart';
import '../../core/timetable/timetable_repository.dart';
import 'sru_otp_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SruLoginScreen extends StatefulWidget {
  final String role;

  const SruLoginScreen({super.key, required this.role});

  @override
  State<SruLoginScreen> createState() => _SruLoginScreenState();
}

class _SruLoginScreenState extends State<SruLoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  bool _rememberMe = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    final savedId = StorageService.getUserIdentifier();
    if (savedId != null && savedId.isNotEmpty) {
      _identifierController.text = savedId;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatErrorMessage(dynamic error) {
    if (error == null) return '';
    final msg = error.toString();
    if (error is TimeoutException || msg.contains('TimeoutException')) {
      return 'The SRU portal took too long to respond. If you received an OTP SMS, tap "Enter OTP" below.';
    }
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return 'Unable to reach SRU portal. Please check your internet connection.';
    }
    if (error is SruAuthException) {
      return error.message;
    }
    return msg.replaceAll(RegExp(r'^(Exception|Error|SruAuthException):\s*'), '');
  }

  void _navigateToOtpScreen() {
    final id = _identifierController.text.trim();
    if (id.isEmpty) {
      setState(() => _errorMessage = 'Please enter your ID, mobile number, or email first.');
      return;
    }
    AuthRepository.instance.setRole(widget.role);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SruOtpScreen()),
    );
  }

  void _login() async {
    final id = _identifierController.text.trim();
    final password = _passwordController.text;
    if (id.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both your identifier and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AuthRepository.instance.setRole(widget.role);
      await AuthRepository.instance.login(
        id,
        password,
        rememberMe: _rememberMe,
      );

      if (mounted) {
        if (AuthRepository.instance.state == AuthState.awaitingOTP) {
          TextInput.finishAutofillContext(shouldSave: true);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const SruOtpScreen()),
          );
        } else if (AuthRepository.instance.state == AuthState.authenticated) {
          // Authenticated successfully! Only now is it safe to persist the user role and identifier.
          await StorageService.setUserMode(widget.role);
          await StorageService.saveUserIdentifier(id);
          if (RegExp(r'\b2[0-9][0-9A-Za-z]{2}[A-Za-z0-9]{6}\b').hasMatch(id)) {
            await StorageService.saveStudentRollNumber(id);
          }
          TextInput.finishAutofillContext(shouldSave: true);
          try {
            await SyncService.instance.syncTimetable(force: true).timeout(const Duration(seconds: 20));
          } catch (e) {
            debugPrint('[LOGIN] Direct auth sync caught non-fatal: $e');
          }
          TimetableRepository.instance.loadFromCache();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 0)),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _formatErrorMessage(e);
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.role == 'student' ? 'Student Login' : 'Faculty Login';
    
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: Text(title, style: AppConstants.getHeadline()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Sign in to SRU Portal',
                style: AppConstants.getHeadline().copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'ⓘ Please use your SRU-registered mobile number or official SRU email and password to log in.\n\n🔒 Your password will not be saved.',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage!,
                        style: AppConstants.getBodyMedium(color: AppConstants.error),
                      ),
                      if (_errorMessage!.contains('OTP') || _errorMessage!.contains('SMS')) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _navigateToOtpScreen,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Enter OTP code',
                                style: AppConstants.getBodyMedium(color: AppConstants.primary).copyWith(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward, size: 16, color: AppConstants.primary),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _identifierController,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      enableSuggestions: true,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Student ID / Mobile / SRU Email',
                        hintText: 'e.g. 2103A51000 or email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      enableSuggestions: false,
                      autocorrect: false,
                      onSubmitted: (_) {
                        if (!_isLoading) _login();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: AppConstants.primary,
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? true;
                          });
                        },
                      ),
                      Text('Remember me', style: AppConstants.getBodyMedium()),
                    ],
                  ),
                  TextButton(
                    onPressed: () async {
                      final url = Uri.parse('https://www.sruniv.com/forget-password');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      'Forgot password?',
                      style: AppConstants.getBodyMedium(color: AppConstants.primary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primary,
                  foregroundColor: AppConstants.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _navigateToOtpScreen,
                  child: Text(
                    'Already received an OTP? Enter code',
                    style: AppConstants.getBodyMedium(color: AppConstants.primary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => SruLoginScreen(
                              role: widget.role == 'student' ? 'faculty' : 'student',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        widget.role == 'student' ? 'Faculty Login' : 'Student Login',
                        style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                      ),
                    ),
                    const Text(' • ', style: TextStyle(color: AppConstants.textSecondary)),
                    TextButton(
                      onPressed: () async {
                        final url = Uri.parse(widget.role == 'student'
                            ? 'https://www.sruniv.com/student-login'
                            : 'https://timetable.sruniv.com/login');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        widget.role == 'student' ? 'Student Portal' : 'Help / Support',
                        style: AppConstants.getBodyMedium(color: AppConstants.primary).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
