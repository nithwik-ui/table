import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/api.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../dashboard/dashboard_screen.dart';

class FacultySelectionScreen extends StatefulWidget {
  const FacultySelectionScreen({super.key});

  @override
  State<FacultySelectionScreen> createState() => _FacultySelectionScreenState();
}

class _FacultySelectionScreenState extends State<FacultySelectionScreen> {
  List<dynamic> _allFaculty = [];
  List<dynamic> _filteredFaculty = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchFaculty() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Please enter at least 2 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      final facultyList = await ApiService.facultySearch(query);
      setState(() {
        _allFaculty = facultyList;
        _filteredFaculty = facultyList;
        _isLoading = false;
      });
      if (facultyList.isEmpty) {
        setState(() => _error = 'No active faculty found.');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to search faculty. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showLoginDialog(dynamic faculty) {
    bool isActivation = false;
    final passwordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    String dialogError = '';
    bool dialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppConstants.surface,
              title: Text(isActivation ? 'Activate Account' : 'Faculty Login', style: AppConstants.getHeadline().copyWith(fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Logging in as: ${faculty['faculty_name']}', style: AppConstants.getBodyMedium()),
                    const SizedBox(height: 16),
                    if (dialogError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(dialogError, style: const TextStyle(color: AppConstants.error, fontSize: 13)),
                      ),
                    
                    if (!isActivation)
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else ...[
                      TextField(
                        controller: passwordCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Activation Code (SRU#...)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPasswordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmPasswordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setStateDialog(() {
                          isActivation = !isActivation;
                          dialogError = '';
                          passwordCtrl.clear();
                          newPasswordCtrl.clear();
                          confirmPasswordCtrl.clear();
                        });
                      },
                      child: Text(isActivation ? 'Already activated? Login here.' : 'First time? Activate account.'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                  onPressed: dialogLoading ? null : () async {
                    setStateDialog(() { dialogError = ''; dialogLoading = true; });
                    try {
                      Map<String, dynamic> res;
                      if (isActivation) {
                        if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                          throw Exception('Passwords do not match');
                        }
                        res = await ApiService.facultyActivate(
                          faculty['id'], 
                          passwordCtrl.text.trim(), 
                          newPasswordCtrl.text
                        );
                      } else {
                        res = await ApiService.facultyLogin(
                          faculty['id'], 
                          passwordCtrl.text
                        );
                      }

                      if (res['success'] == true) {
                        Navigator.pop(ctx);
                        _proceedWithFaculty(faculty['id'], faculty['faculty_name'], res['token']);
                      } else {
                        throw Exception('Authentication failed');
                      }
                    } catch (e) {
                      setStateDialog(() {
                        dialogError = e.toString().replaceAll('Exception: ', '');
                        dialogLoading = false;
                      });
                    }
                  },
                  child: dialogLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isActivation ? 'Activate' : 'Login', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _proceedWithFaculty(String facultyId, String facultyName, String token) async {
    setState(() {
      _isSaving = true;
      _error = '';
    });
    
    try {
      // 1. Save Token
      await StorageService.setFacultyToken(token);

      // 2. Fetch timetable and holidays
      final timetable = await ApiService.fetchFacultyTimetable(facultyId);
      final overrides = await ApiService.fetchCalendarOverrides('', 'faculty');
      
      // 3. Save data locally
      await StorageService.clearFacultySelection();
      await StorageService.saveFacultySelection(
        facultyId: facultyId,
        facultyName: facultyName,
      );
      await StorageService.saveFacultyTimetableCache(timetable);
      await StorageService.saveCalendarOverridesCache(overrides);
      await StorageService.saveFacultyLastSyncedAt(DateTime.now());

      // 4. Try to register device token as faculty
      String fcmToken = 'local_device';
      try {
        final t = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
        if (t != null) {
          fcmToken = t;
        }
      } catch (_) {}
      
      await ApiService.registerDevice(
        fcmToken,
        '', // No batch id for faculty
        userMode: 'faculty',
        facultyId: facultyId,
      );
      
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load timetable. Please check your connection and try again.';
        _isSaving = false;
      });
      // Important: if we failed to fetch the timetable, wipe the token so they don't get stuck half-logged-in
      await StorageService.clearFacultySelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Faculty Portal Login'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingContainer),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Enter your name...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: AppConstants.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _searchFaculty(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                    ),
                    onPressed: _isLoading ? null : _searchFaculty,
                    child: const Text('Search', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
            
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppConstants.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error,
                          style: AppConstants.getBodyMedium(color: AppConstants.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredFaculty.isEmpty
                      ? Center(
                          child: Text(
                            'Search for your name to login.',
                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredFaculty.length,
                          itemBuilder: (context, index) {
                            final faculty = _filteredFaculty[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppConstants.primaryContainer,
                                child: Icon(Icons.person, color: AppConstants.primary),
                              ),
                              title: Text(
                                faculty['faculty_name'] ?? '',
                                style: AppConstants.getBodyLarge().copyWith(fontWeight: FontWeight.w500),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _isSaving ? null : () => _showLoginDialog(faculty),
                            );
                          },
                        ),
            ),
            
            if (_isSaving)
              Container(
                color: Colors.black12,
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Authenticating and fetching timetable...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
