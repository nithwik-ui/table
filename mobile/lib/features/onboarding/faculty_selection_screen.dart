import 'package:flutter/material.dart';
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
  bool _isLoading = true;
  bool _isSaving = false;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFaculty();
    _searchController.addListener(_filterFaculty);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFaculty() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      final facultyList = await ApiService.fetchFacultyList();
      setState(() {
        _allFaculty = facultyList;
        _filteredFaculty = facultyList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load faculty list. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _filterFaculty() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFaculty = _allFaculty.where((f) {
        final name = (f['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _selectFaculty(dynamic faculty) async {
    setState(() {
      _isSaving = true;
      _error = '';
    });
    
    try {
      final facultyId = faculty['id'].toString();
      final facultyName = faculty['name'].toString();
      
      // Fetch timetable
      final timetable = await ApiService.fetchFacultyTimetable(facultyId);
      
      // Save data locally
      await StorageService.saveFacultySelection(
        facultyId: facultyId,
        facultyName: facultyName,
      );
      await StorageService.saveFacultyTimetableCache(timetable);
      await StorageService.saveFacultyLastSyncedAt(DateTime.now());
      
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to load timetable for selected faculty. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Select Faculty'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingContainer),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search faculty name...',
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
                            'No faculty found',
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
                                faculty['name'],
                                style: AppConstants.getBodyLarge().copyWith(fontWeight: FontWeight.w500),
                              ),
                              onTap: _isSaving ? null : () => _selectFaculty(faculty),
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
                    Text('Fetching timetable...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
