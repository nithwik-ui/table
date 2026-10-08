import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/sync.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_state.dart';
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

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final id = _identifierController.text.trim();
    await StorageService.setUserMode(widget.role);
    await StorageService.saveUserIdentifier(id);
    if (RegExp(r'\b2[0-9][0-9A-Za-z]{2}[A-Za-z0-9]{6}\b').hasMatch(id)) {
      await StorageService.saveStudentRollNumber(id);
    }

    try {
      AuthRepository.instance.setRole(widget.role);
      await AuthRepository.instance.login(
        id,
        _passwordController.text,
        rememberMe: _rememberMe,
      );

      if (mounted) {
        if (AuthRepository.instance.state == AuthState.awaitingOTP) {
          TextInput.finishAutofillContext();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const SruOtpScreen()),
          );
        } else if (AuthRepository.instance.state == AuthState.authenticated) {
          TextInput.finishAutofillContext();
          SyncService.instance.syncTimetable();
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
          _errorMessage = e.toString();
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
                'Use your registered mobile number or official SRU email.',
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
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _identifierController,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Mobile / SRU Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onEditingComplete: () => TextInput.finishAutofillContext(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
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
              const SizedBox(height: 8),
              Center(
                child: TextButton(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
