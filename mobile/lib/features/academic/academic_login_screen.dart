import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/auth/secure_session_store.dart';
import '../../core/sraap/sraap_auth_manager.dart';
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
    SraapSessionManager.instance.isLoginFlowActive = true;
    final savedRoll = StorageService.getStudentRollNumber();
    if (savedRoll != null && savedRoll.isNotEmpty) {
      _enrollmentCtrl.text = savedRoll.toUpperCase();
    }
    _restoreSavedCredentials();
    _fetchCaptcha(forceFreshSession: true);
  }

  Future<void> _restoreSavedCredentials() async {
    try {
      final creds =
          await SecureSessionStore.getSession(role: 'sraap_credentials');
      if (creds != null) {
        if (_enrollmentCtrl.text.isEmpty && creds['sraap_roll'] != null) {
          _enrollmentCtrl.text = creds['sraap_roll'].toString().toUpperCase();
        }
        if (_passwordCtrl.text.isEmpty && creds['sraap_pass'] != null) {
          _passwordCtrl.text = creds['sraap_pass'].toString();
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchCaptcha({bool forceFreshSession = false}) async {
    if (!mounted) return;
    setState(() {
      _isRefreshingCaptcha = true;
    });

    final bytes = await SraapSessionManager.instance.fetchCaptcha(
      forceFreshSession: forceFreshSession,
    );

    if (mounted) {
      setState(() {
        _captchaBytes = bytes;
        _isRefreshingCaptcha = false;
        if (bytes == null) {
          _errorMessage ??=
              "Unable to load CAPTCHA. Tap Refresh CAPTCHA or check your connection.";
        }
      });
    }
  }

  Future<void> _login() async {
    if (_isLoading || _isRefreshingCaptcha) return;

    final roll = _enrollmentCtrl.text.trim().toUpperCase();
    final password = _passwordCtrl.text;
    final captcha = _captchaCtrl.text.trim();

    if (roll.isEmpty || password.isEmpty || captcha.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields.");
      return;
    }

    if (_captchaBytes == null) {
      setState(
        () => _errorMessage =
            "CAPTCHA is not loaded yet. Tap Refresh CAPTCHA and try again.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await SraapAuthManager.submitLogin(
        enrollment: roll,
        password: password,
        captcha: captcha,
      );

      if (!mounted) return;

      if (result.success) {
        // Success - prompt OS / Google Password Manager to save credentials
        TextInput.finishAutofillContext(shouldSave: true);
        await StorageService.setSraapConnected(true);
        await SraapSessionManager.instance.markAuthenticated();
        await StorageService.saveStudentRollNumber(roll);
        await SecureSessionStore.saveSession({
          'sraap_roll': roll,
          'sraap_pass': password,
        }, role: 'sraap_credentials');
        SraapAcademicService.instance.startKeepAlive();
        try {
          await SraapAcademicService.instance.getAcademicData(
            forceRefresh: true,
          );
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        switch (result.error) {
          case SraapLoginError.portalUnavailable:
            setState(
              () => _errorMessage =
                  "SRAAP has blocked your current WiFi network due to too many requests. Please switch to Mobile Data (4G/5G) and try again.",
            );
            break;
          case SraapLoginError.invalidCaptcha:
            setState(
              () => _errorMessage = "Incorrect CAPTCHA. Please try again.",
            );
            _captchaCtrl.clear();
            await _fetchCaptcha(forceFreshSession: false);
            break;
          case SraapLoginError.invalidCredentials:
            setState(
              () => _errorMessage =
                  "Incorrect enrollment number or password.",
            );
            break;
          case SraapLoginError.timeout:
          case SraapLoginError.networkUnavailable:
            setState(
              () => _errorMessage =
                  "Unable to reach SRAAP. Please check your connection and try again.",
            );
            break;
          case SraapLoginError.sessionExpired:
          case SraapLoginError.unknown:
          case null:
            setState(
              () => _errorMessage =
                  "Login session expired or could not be verified. Please enter the new CAPTCHA and try again.",
            );
            _captchaCtrl.clear();
            await _fetchCaptcha(forceFreshSession: true);
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('TimeoutException')) {
          setState(
            () => _errorMessage =
                "Unable to reach SRAAP. Please check your connection and try again.",
          );
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
    SraapSessionManager.instance.isLoginFlowActive = false;
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
        iconTheme: IconThemeData(color: AppConstants.primary),
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
                style: AppConstants.getBodyMedium(
                  color: AppConstants.textSecondary,
                ),
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
                      Icon(
                        Icons.error_outline,
                        color: AppConstants.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppConstants.getBodyMedium(
                            color: AppConstants.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Credentials with Autofill Support (sraap.in)
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Roll Number'),
                    TextField(
                      controller: _enrollmentCtrl,
                      style: AppConstants.getBodyLarge(color: AppConstants.textPrimary),
                      cursorColor: AppConstants.primary,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      ],
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Enter roll number',
                        hintStyle: AppConstants.getBodyMedium(color: AppConstants.textMuted),
                        filled: true,
                        fillColor: AppConstants.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusButton,
                          ),
                          borderSide: BorderSide(
                            color: AppConstants.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusButton,
                          ),
                          borderSide: BorderSide(
                            color: AppConstants.outline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    _buildLabel('Password'),
                    TextField(
                      controller: _passwordCtrl,
                      style: AppConstants.getBodyLarge(color: AppConstants.textPrimary),
                      cursorColor: AppConstants.primary,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Enter password',
                        hintStyle: AppConstants.getBodyMedium(color: AppConstants.textMuted),
                        filled: true,
                        fillColor: AppConstants.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusButton,
                          ),
                          borderSide: BorderSide(
                            color: AppConstants.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusButton,
                          ),
                          borderSide: BorderSide(
                            color: AppConstants.outline,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CAPTCHA Display
              _buildLabel('CAPTCHA'),
              Container(
                decoration: BoxDecoration(
                  color: AppConstants.surface,
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusButton,
                  ),
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
                          ? Image.memory(
                              _captchaBytes!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => Text(
                                'Failed to render CAPTCHA image',
                                style: AppConstants.getBodyMedium(),
                              ),
                            )
                          : Text(
                              'Failed to load image',
                              style: AppConstants.getBodyMedium(),
                            ),
                    ),
                    Divider(height: 1, color: AppConstants.outline),
                    TextButton.icon(
                      onPressed: (_isRefreshingCaptcha || _isLoading)
                          ? null
                          : () {
                              setState(() => _errorMessage = null);
                              _fetchCaptcha(forceFreshSession: false);
                            },
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
                style: AppConstants.getBodyLarge(color: AppConstants.textPrimary),
                cursorColor: AppConstants.primary,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Enter CAPTCHA',
                  hintStyle: AppConstants.getBodyMedium(color: AppConstants.textMuted),
                  filled: true,
                  fillColor: AppConstants.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusButton,
                    ),
                    borderSide: BorderSide(color: AppConstants.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusButton,
                    ),
                    borderSide: BorderSide(color: AppConstants.outline),
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
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusButton,
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Connect SRAAP',
                          style: AppConstants.getBodyLarge(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.bold),
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
        style: AppConstants.getBodyMedium().copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
