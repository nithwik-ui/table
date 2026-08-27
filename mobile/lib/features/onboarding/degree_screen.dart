import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api.dart';
import '../../core/storage.dart';
import 'year_screen.dart';

const Map<String, String> degreeDescriptions = {
  'BTECH-CSE': 'Computer Science & Engineering',
  'BCA-CSAI': 'Computer Applications (AI focus)',
  'MBA-BM': 'Business Management',
  'PhD-ECE': 'Electronics & Communication',
  'BTECH-ECE': 'Electronics & Communication Engineering',
  'BTECH-EEE': 'Electrical & Electronics Engineering',
  'BTECH-ME': 'Mechanical Engineering',
  'BTECH-CE': 'Civil Engineering',
  'MCA-CSE': 'Master of Computer Applications',
};

class DegreeScreen extends StatefulWidget {
  const DegreeScreen({super.key});

  @override
  State<DegreeScreen> createState() => _DegreeScreenState();
}

class _DegreeScreenState extends State<DegreeScreen> {
  List<String> _allDegrees = [];
  List<String> _filteredDegrees = [];
  String? _selectedDegree;
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDegrees();
  }

  void _loadDegrees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final cached = StorageService.getDegreesCache();
      if (cached != null && cached.isNotEmpty) {
        final list = cached.cast<String>();
        setState(() {
          _allDegrees = list;
          _filteredDegrees = list;
          _isLoading = false;
        });
        // Background refresh
        _refreshDegrees();
        return;
      }
      
      await _refreshDegrees();
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not fetch degrees. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDegrees() async {
    try {
      final list = await ApiService.fetchDegrees();
      final codes = list.map((item) => (item['source_value'] as String)).toList();
      
      await StorageService.saveDegreesCache(codes);
      
      if (mounted) {
        setState(() {
          _allDegrees = codes;
          _filteredDegrees = codes;
          _isLoading = false;
        });
        _filterDegrees(_searchController.text);
      }
    } catch (e) {
      if (_allDegrees.isEmpty && mounted) {
        setState(() {
          _errorMessage = 'Could not fetch degrees. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterDegrees(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredDegrees = _allDegrees;
      });
    } else {
      setState(() {
        _filteredDegrees = _allDegrees
            .where((deg) => deg.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  void _onContinue() {
    if (_selectedDegree != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => YearScreen(degree: _selectedDegree!),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppConstants.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'sru',
          style: AppConstants.getDisplay(color: AppConstants.primary).copyWith(fontSize: 22),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Progress dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppConstants.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppConstants.textSecondary, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppConstants.textSecondary, width: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Choose your degree.',
                style: AppConstants.getHeadline().copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),
              // Search input
              TextField(
                controller: _searchController,
                onChanged: _filterDegrees,
                style: AppConstants.getBodyMedium(),
                decoration: InputDecoration(
                  hintText: 'Search degree — e.g. BTECH-CSE',
                  hintStyle: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppConstants.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppConstants.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: const BorderSide(color: AppConstants.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // List contents
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
                    : _errorMessage.isNotEmpty && _allDegrees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_errorMessage, textAlign: TextAlign.center, style: AppConstants.getBodyMedium(color: AppConstants.error)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadDegrees,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                                  child: const Text('Try Again'),
                                )
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredDegrees.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final code = _filteredDegrees[index];
                              final subtitle = degreeDescriptions[code];
                              final isSelected = _selectedDegree == code;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDegree = code;
                                  });
                                },
                                borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppConstants.surface,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                    border: Border.all(
                                      color: isSelected ? AppConstants.primary : AppConstants.outline,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: AppConstants.shadowLevel1,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              code,
                                              style: AppConstants.getHeadline().copyWith(fontSize: 16, color: isSelected ? AppConstants.primary : AppConstants.textPrimary),
                                            ),
                                            if (subtitle != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                subtitle,
                                                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle, color: AppConstants.primary, size: 22)
                                      else
                                        const Icon(Icons.chevron_right, color: AppConstants.textSecondary, size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              // Continue button
              ElevatedButton(
                onPressed: _selectedDegree != null ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primary,
                  disabledBackgroundColor: AppConstants.outline,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: AppConstants.getBodyLarge(color: _selectedDegree != null ? AppConstants.onPrimary : AppConstants.textSecondary).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: _selectedDegree != null ? AppConstants.onPrimary : AppConstants.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
