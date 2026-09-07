import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/api.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/notifications.dart';
import '../../core/sync.dart';
import '../dashboard/dashboard_screen.dart';

class FacultySelectionScreen extends StatefulWidget {
  const FacultySelectionScreen({super.key});

  @override
  State<FacultySelectionScreen> createState() => _FacultySelectionScreenState();
}

class _FacultySelectionScreenState extends State<FacultySelectionScreen> {
  List<dynamic> _allFaculty = [];
  List<dynamic> _filteredFaculty = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFacultyList();
    _searchController.addListener(_filterFaculty);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFacultyList() async {
    try {
      final list = await ApiService.fetchFacultyList();
      if (mounted) {
        setState(() {
          _allFaculty = list;
          _filteredFaculty = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load faculty list. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterFaculty() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredFaculty = _allFaculty;
      } else {
        _filteredFaculty = _allFaculty.where((f) {
          final name = (f['name'] as String).toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  void _showLoginDialog(dynamic faculty) {
    final passwordCtrl = TextEditingController();
    String dialogError = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppConstants.surface,
              title: Text('Faculty Login', style: AppConstants.getHeadline().copyWith(fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Logging in as: ${faculty['name']}', style: AppConstants.getBodyMedium()),
                  const SizedBox(height: 16),
                  if (dialogError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(dialogError, style: const TextStyle(color: AppConstants.error, fontSize: 13)),
                    ),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                  onPressed: () {
                    final expectedPassword = 'Sru#${faculty['id']}';
                    if (passwordCtrl.text.trim() == expectedPassword) {
                      Navigator.pop(ctx);
                      _proceedWithFaculty(faculty['id'].toString(), faculty['name'].toString());
                    } else {
                      setStateDialog(() {
                        dialogError = 'Incorrect password.';
                      });
                    }
                  },
                  child: const Text('Login', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _proceedWithFaculty(String facultyId, String facultyName) async {
    setState(() {
      _isSaving = true;
      _error = '';
    });
    
    try {
      // 1. Save local token (no longer using JWT backend)
      await StorageService.setFacultyToken('local_auth_token_$facultyId');

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
      await StorageService.saveFacultyCalendarOverridesCache(overrides);
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
      
      // 5. Successfully authenticated and setup. Now we switch mode!
      await NotificationService.clearModeReminders('student');
      await StorageService.setUserMode('faculty');
      await NotificationService.reconcileReminders();
      SyncService.instance.syncTimetable();

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
      // Wipe the token so they don't get stuck half-logged-in
      await StorageService.clearFacultySelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Faculty Portal'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingContainer),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for your name...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppConstants.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: BorderSide.none,
                  ),
                ),
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
                            'No faculty found.',
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
                                faculty['name'] ?? '',
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
