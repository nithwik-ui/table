import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/auth/secure_session_store.dart';
import '../../core/sraap/sraap_session_manager.dart';
import '../../core/sraap/sraap_academic_service.dart';

class AcademicLoginScreen extends StatefulWidget {
  const AcademicLoginScreen({super.key});

  @override
  State<AcademicLoginScreen> createState() => _AcademicLoginScreenState();
}

class _AcademicLoginScreenState extends State<AcademicLoginScreen> {
  final TextEditingController _enrollmentCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _captchaCtrl = TextEditingController();
  bool _obscurePassword = true;
  
  bool _isLoading = false;
  bool _isRefreshingCaptcha = true;
  Uint8List? _captchaBytes;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final savedRoll = StorageService.getStudentRollNumber();
    if (savedRoll != null && savedRoll.isNotEmpty) {
      _enrollmentCtrl.text = savedRoll;
    }
    _restoreSavedCredentials();
    _fetchCaptcha();
  }

  Future<void> _restoreSavedCredentials() async {
    try {
      final creds = await SecureSessionStore.getSession(role: 'sraap_credentials');
      if (creds != null) {
        if (_enrollmentCtrl.text.isEmpty && creds['sraap_roll'] != null) {
          _enrollmentCtrl.text = creds['sraap_roll'].toString();
        }
        if (_passwordCtrl.text.isEmpty && creds['sraap_pass'] != null) {
          _passwordCtrl.text = creds['sraap_pass'].toString();
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchCaptcha() async {
    setState(() {
      _isRefreshingCaptcha = true;
      _errorMessage = null;
    });
    
    final bytes = await SraapSessionManager.instance.fetchCaptcha();
    
    if (mounted) {
      setState(() {
        _captchaBytes = bytes;
        _isRefreshingCaptcha = false;
        if (bytes == null) {
          _errorMessage = "Unable to load CAPTCHA. Tap the refresh icon or check connection.";
        }
      });
    }
  }

  Future<void> _login() async {
    if (_enrollmentCtrl.text.isEmpty || _passwordCtrl.text.isEmpty || _captchaCtrl.text.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await SraapSessionManager.instance.login(
        enrollment: _enrollmentCtrl.text,
        password: _passwordCtrl.text,
        captcha: _captchaCtrl.text,
      );

      if (!mounted) return;

      if (res.statusCode == 302 || res.statusCode == 301 || res.body.toLowerCase().contains('logout') || res.bodyBytes.length > 10000) {
        // Success
        await StorageService.setSraapConnected(true);
        await StorageService.saveStudentRollNumber(_enrollmentCtrl.text.trim());
        await SecureSessionStore.saveSession({
          'sraap_roll': _enrollmentCtrl.text.trim(),
          'sraap_pass': _passwordCtrl.text.trim(),
        }, role: 'sraap_credentials');
        SraapAcademicService.instance.startKeepAlive();
        try {
          await SraapAcademicService.instance.getAcademicData(forceRefresh: true);
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (res.body.toLowerCase().contains('access restricted') || res.body.toLowerCase().contains('shared public ip')) {
          setState(() => _errorMessage = "SRAAP has blocked your current WiFi network due to too many requests. Please switch to Mobile Data (4G/5G) and try again.");
        } else if (res.body.toLowerCase().contains('captcha')) {
          setState(() => _errorMessage = "Incorrect CAPTCHA. Please try again.");
        } else {
          setState(() => _errorMessage = "Incorrect enrollment number or password.");
        }
        _captchaCtrl.clear();
        _fetchCaptcha(); // Refresh captcha on failure
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('TimeoutException')) {
          setState(() => _errorMessage = "Unable to reach SRAAP. Please check your connection and try again.");
        } else {
          setState(() => _errorMessage = "Couldn't connect to SRAAP.");
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _enrollmentCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: Text('Connect to SRAAP', style: AppConstants.getHeadline()),
        backgroundColor: AppConstants.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppConstants.primary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign in with your SRAAP account',
                style: AppConstants.getHeadline(),
              ),
              const SizedBox(height: 8),
              Text(
                'ⓘ Please use your roll number and password to log in.\n\n🔒 Your password will not be saved.',
                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
              ),
              const SizedBox(height: 24),
              
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppConstants.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppConstants.getBodyMedium(color: AppConstants.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Enrollment Field
              _buildLabel('Roll Number'),
              TextField(
                controller: _enrollmentCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter roll number',
                  filled: true,
                  fillColor: AppConstants.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.outline),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              _buildLabel('Password'),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  filled: true,
                  fillColor: AppConstants.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.outline),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppConstants.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CAPTCHA Display
              _buildLabel('CAPTCHA'),
              Container(
                decoration: BoxDecoration(
                  color: AppConstants.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                  border: Border.all(color: AppConstants.outline),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 80,
                      alignment: Alignment.center,
                      child: _isRefreshingCaptcha
                          ? const CircularProgressIndicator()
                          : _captchaBytes != null
                              ? Image.memory(_captchaBytes!, fit: BoxFit.contain)
                              : Text('Failed to load image', style: AppConstants.getBodyMedium()),
                    ),
                    Divider(height: 1, color: AppConstants.outline),
                    TextButton.icon(
                      onPressed: _isRefreshingCaptcha ? null : _fetchCaptcha,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh CAPTCHA'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppConstants.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CAPTCHA Input
              TextField(
                controller: _captchaCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter CAPTCHA',
                  filled: true,
                  fillColor: AppConstants.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.outline),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
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
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
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
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppConstants.getBodyMedium().copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
