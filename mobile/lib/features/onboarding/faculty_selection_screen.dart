import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/api.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/notifications.dart';
import '../../core/timetable/timetable_repository.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/secure_session_store.dart';
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
          final name = (f['name']?.toString() ?? '').toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _proceedWithFaculty(String facultyId, String facultyName) async {
    setState(() {
      _isSaving = true;
      _error = '';
    });

    try {
      await StorageService.setFacultyToken('local_auth_token_$facultyId');

      final timetable = await ApiService.fetchFacultyTimetable(facultyId);
      final overrides = await ApiService.fetchCalendarOverrides('', 'faculty');

      await StorageService.clearFacultySelection();
      await StorageService.saveProfile({
        'id': facultyId,
        'faculty_id': facultyId,
        'name': facultyName,
        'role': 'faculty',
      });
      await StorageService.saveUserName(facultyName);
      await StorageService.saveUserIdentifier(facultyId);
      await StorageService.saveFacultyTimetableCache(timetable);
      await StorageService.saveFacultyCalendarOverridesCache(overrides);

      final syncedAt = DateTime.now();
      await StorageService.saveFacultyLastSyncedAt(syncedAt);

      await SecureSessionStore.saveSession({
        'cookie': 'faculty_mode=$facultyId',
        'role': 'faculty',
        'identifier': facultyId,
      }, role: 'faculty');

      await StorageService.setUserMode('faculty');
      await AuthRepository.instance.restoreSession();

      TimetableRepository.instance.updateTimetable(
        timetable,
        source: 'cloudflare_faculty',
        syncedAt: syncedAt,
      );

      String fcmToken = 'local_device';
      try {
        final token = kIsWeb
            ? await FirebaseMessaging.instance
                .getToken(vapidKey: AppConstants.fcmVapidKey)
                .timeout(const Duration(seconds: 5))
            : await FirebaseMessaging.instance
                .getToken()
                .timeout(const Duration(seconds: 5));
        if (token != null) fcmToken = token;
      } catch (_) {}

      await ApiService.registerDevice(
        fcmToken,
        '',
        userMode: 'faculty',
        facultyId: facultyId,
      );

      if (StorageService.isClassRemindersEnabled()) {
        await NotificationService.reconcileReminders();
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load faculty timetable. Please check your connection and try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppConstants.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Select Faculty Profile',
          style: AppConstants.getHeadline().copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingContainer),
              child: TextField(
                controller: _searchController,
                style: AppConstants.getBodyLarge(),
                decoration: InputDecoration(
                  hintText: 'Search for your name...',
                  hintStyle: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                  prefixIcon: Icon(Icons.search, color: AppConstants.textSecondary),
                  filled: true,
                  fillColor: AppConstants.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: BorderSide(color: AppConstants.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: BorderSide(color: AppConstants.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: BorderSide(color: AppConstants.primary, width: 1.5),
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
                    color: AppConstants.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppConstants.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error,
                          style: AppConstants.getBodyMedium(color: AppConstants.errorText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppConstants.primary))
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
                            final id = faculty['id']?.toString() ?? '';
                            final name = faculty['name']?.toString() ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppConstants.secondaryContainer,
                                child: Icon(Icons.person, color: AppConstants.primary),
                              ),
                              title: Text(
                                name,
                                style: AppConstants.getBodyLarge().copyWith(fontWeight: FontWeight.w600),
                              ),
                              trailing: Icon(Icons.chevron_right, color: AppConstants.textSecondary),
                              onTap: _isSaving ? null : () => _proceedWithFaculty(id, name),
                            );
                          },
                        ),
            ),
            if (_isSaving)
              Container(
                color: AppConstants.surfaceElevated,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppConstants.primary),
                    const SizedBox(width: 16),
                    Text('Loading faculty timetable...', style: AppConstants.getBodyMedium()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

