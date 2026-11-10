import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api.dart';
import '../../core/storage.dart';
import 'syncing_screen.dart';

class BatchScreen extends StatefulWidget {
  final String degree;
  final String year;

  const BatchScreen({
    super.key,
    required this.degree,
    required this.year,
  });

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  List<Map<String, dynamic>> _allBatches = [];
  List<Map<String, dynamic>> _filteredBatches = [];
  Map<String, dynamic>? _selectedBatch;
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existingName = StorageService.getUserName();
    if (existingName != null && existingName.isNotEmpty && existingName != 'Student') {
      _nameController.text = existingName;
    }
    _loadBatches();
  }

  void _loadBatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final cached = StorageService.getBatchesCache(widget.degree, widget.year);
      if (cached != null && cached.isNotEmpty) {
        final list = cached.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          return {
            'id': m['id'].toString(),
            'batch_code': m['batch_code'].toString(),
          };
        }).toList();

        setState(() {
          _allBatches = list;
          _filteredBatches = list;
          _isLoading = false;
        });
        _refreshBatches();
        return;
      }
      await _refreshBatches();
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load batches. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshBatches() async {
    try {
      final list = await ApiService.fetchBatches(widget.degree, widget.year);
      final parsed = list.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        return {
          'id': m['id'].toString(),
          'batch_code': m['batch_code'].toString(),
        };
      }).toList();

      await StorageService.saveBatchesCache(widget.degree, widget.year, parsed);

      if (mounted) {
        setState(() {
          _allBatches = parsed;
          _filteredBatches = parsed;
          _isLoading = false;
        });
        _filterBatches(_searchController.text);
      }
    } catch (e) {
      if (_allBatches.isEmpty && mounted) {
        setState(() {
          _errorMessage = 'Could not load batches. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterBatches(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredBatches = _allBatches;
      });
    } else {
      setState(() {
        _filteredBatches = _allBatches
            .where((b) => (b['batch_code'] as String)
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  Future<void> _onContinue() async {
    if (_selectedBatch != null) {
      final enteredName = _nameController.text.trim();
      if (enteredName.isNotEmpty) {
        await StorageService.saveUserName(enteredName);
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SyncingScreen(
            degree: widget.degree,
            year: widget.year,
            batchId: _selectedBatch!['id'] as String,
            batchCode: _selectedBatch!['batch_code'] as String,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
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
          icon: Icon(Icons.arrow_back_ios, color: AppConstants.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Select Batch',
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppConstants.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                      border: Border.all(color: AppConstants.outline),
                    ),
                    child: Text(
                      '${widget.year} Year',
                      style: AppConstants.getLabelSmall(color: AppConstants.primary).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Select your batch',
                style: AppConstants.getHeadline().copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your section/batch code (e.g. 24BTCAICYB02). No SRU portal password required.',
                style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                style: AppConstants.getBodyMedium(),
                decoration: InputDecoration(
                  hintText: 'Your Name (optional, for greeting)',
                  hintStyle: AppConstants.getBodyMedium(color: AppConstants.textMuted),
                  prefixIcon: Icon(Icons.person_outline, color: AppConstants.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppConstants.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: _filterBatches,
                style: AppConstants.getBodyLarge(),
                decoration: InputDecoration(
                  hintText: 'Search batch code (e.g. CYB02, CSE)...',
                  hintStyle: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                  prefixIcon: Icon(Icons.search, color: AppConstants.textSecondary),
                  filled: true,
                  fillColor: AppConstants.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: AppConstants.primary))
                    : _errorMessage.isNotEmpty && _allBatches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_errorMessage, style: AppConstants.getBodyMedium(color: AppConstants.error)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadBatches,
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
                            itemCount: _filteredBatches.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final b = _filteredBatches[index];
                              final code = b['batch_code'] as String;
                              final id = b['id'] as String;
                              final isSelected = _selectedBatch != null && _selectedBatch!['id'] == id;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedBatch = b;
                                  });
                                },
                                borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppConstants.primary : AppConstants.surface,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                                    border: Border.all(
                                      color: isSelected ? AppConstants.primary : AppConstants.outline,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: AppConstants.shadowLevel1,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          code,
                                          style: AppConstants.getMonoLabel(
                                            color: isSelected ? AppConstants.onPrimary : AppConstants.textPrimary,
                                          ).copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle, color: AppConstants.onPrimary, size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _selectedBatch != null ? _onContinue : null,
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
                      'Load My Timetable',
                      style: AppConstants.getBodyLarge(
                        color: _selectedBatch != null ? AppConstants.onPrimary : AppConstants.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: _selectedBatch != null ? AppConstants.onPrimary : AppConstants.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

