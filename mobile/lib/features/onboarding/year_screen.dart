import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api.dart';
import '../../core/storage.dart';
import 'batch_screen.dart';

const Map<String, int> yearOrders = {
  'First': 0,
  'Second': 1,
  'Third': 2,
  'Fourth': 3,
  'Fifth': 4,
};

class YearScreen extends StatefulWidget {
  final String degree;

  const YearScreen({super.key, required this.degree});

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  List<String> _years = [];
  String? _selectedYear;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  void _loadYears() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final cached = StorageService.getYearsCache(widget.degree);
      if (cached != null && cached.isNotEmpty) {
        final list = cached.map((e) => e.toString()).where((y) => !y.startsWith('{')).toList();
        if (list.isNotEmpty) {
          _setSortedYears(list);
          _isLoading = false;
          _refreshYears();
          return;
        }
      }
      await _refreshYears();
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load years. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshYears() async {
    try {
      final list = await ApiService.fetchYears(widget.degree);
      final yearNames = list.map((item) {
        if (item is Map) {
          return item['name'] as String;
        }
        return item.toString();
      }).toList();

      await StorageService.saveYearsCache(widget.degree, yearNames);

      if (mounted) {
        _setSortedYears(yearNames);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_years.isEmpty && mounted) {
        setState(() {
          _errorMessage = 'Could not load years. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _setSortedYears(List<String> list) {
    list.sort((a, b) => (yearOrders[a] ?? 99).compareTo(yearOrders[b] ?? 99));
    setState(() {
      _years = list;
    });
  }

  String _getSemesterSubtitle(String yearName, int index) {
    final computedIndex = yearOrders[yearName];
    if (computedIndex != null) {
      final sem1 = computedIndex * 2 + 1;
      final sem2 = computedIndex * 2 + 2;
      return 'Semesters $sem1 & $sem2';
    }
    final sem1 = index * 2 + 1;
    final sem2 = index * 2 + 2;
    return 'Semesters $sem1 & $sem2';
  }

  IconData _getYearIcon(String yearName) {
    switch (yearName) {
      case 'First':
        return Icons.looks_one_outlined;
      case 'Second':
        return Icons.looks_two_outlined;
      case 'Third':
        return Icons.looks_3_outlined;
      case 'Fourth':
        return Icons.looks_4_outlined;
      default:
        return Icons.school_outlined;
    }
  }

  void _onContinue() {
    if (_selectedYear != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BatchScreen(
            degree: widget.degree,
            year: _selectedYear!,
          ),
        ),
      );
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
          'Select Year',
          style: AppConstants.getHeadline().copyWith(fontSize: 18),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppConstants.primary.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
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
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppConstants.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                    border: Border.all(color: AppConstants.outline),
                  ),
                  child: Text(
                    widget.degree,
                    style: AppConstants.getLabelSmall(color: AppConstants.primary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Select academic year',
                style: AppConstants.getHeadline().copyWith(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                'Which year of ${widget.degree} are you currently in?',
                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: AppConstants.primary))
                    : _errorMessage.isNotEmpty && _years.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_errorMessage, style: AppConstants.getBodyMedium(color: AppConstants.error)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadYears,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.primary,
                                    foregroundColor: AppConstants.onPrimary,
                                  ),
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _years.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final name = _years[index];
                              final subtitle = _getSemesterSubtitle(name, index);
                              final icon = _getYearIcon(name);
                              final isSelected = _selectedYear == name;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedYear = name;
                                  });
                                },
                                borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppConstants.primary : AppConstants.surface,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                    border: Border.all(
                                      color: isSelected ? AppConstants.primary : AppConstants.outline,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: AppConstants.shadowLevel1,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.18)
                                              : AppConstants.secondaryContainer,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          icon,
                                          color: isSelected ? AppConstants.onPrimary : AppConstants.primary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$name Year',
                                              style: AppConstants.getHeadline().copyWith(
                                                fontSize: 16,
                                                color: isSelected ? AppConstants.onPrimary : AppConstants.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              subtitle,
                                              style: AppConstants.getBodyMedium(
                                                color: isSelected
                                                    ? AppConstants.onPrimary.withValues(alpha: 0.85)
                                                    : AppConstants.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle, color: AppConstants.onPrimary, size: 24),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _selectedYear != null ? _onContinue : null,
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
                      style: AppConstants.getBodyLarge(
                        color: _selectedYear != null ? AppConstants.onPrimary : AppConstants.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: _selectedYear != null ? AppConstants.onPrimary : AppConstants.textSecondary,
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

