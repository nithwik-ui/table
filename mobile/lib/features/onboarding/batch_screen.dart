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
  Map<String, dynamic>? _selectedBatch; // contains 'id' and 'batch_code'
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
        final list = cached.cast<Map<dynamic, dynamic>>().map((item) {
          return {
            'id': item['id'] as String,
            'batch_code': item['batch_code'] as String,
          };
        }).toList();
        
        setState(() {
          _allBatches = list;
          _filteredBatches = list;
          _isLoading = false;
        });
        // Background refresh
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
        return {
          'id': item['id'] as String,
          'batch_code': item['batch_code'] as String,
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

  void _onContinue() {
    if (_selectedBatch != null) {
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
          'Step 4',
          style: AppConstants.getHeadline().copyWith(fontSize: 18, color: AppConstants.textSecondary),
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
              // Chosen degree and year chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppConstants.secondaryContainer.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                    ),
                    child: Text(
                      widget.degree,
                      style: AppConstants.getLabelSmall(color: AppConstants.onSecondaryContainer).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppConstants.secondaryContainer.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                    ),
                    child: Text(
                      '${widget.year} Year',
                      style: AppConstants.getLabelSmall(color: AppConstants.onSecondaryContainer).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Select your batch.',
                style: AppConstants.getHeadline().copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),
              // Search input
              TextField(
                controller: _searchController,
                onChanged: _filterBatches,
                style: AppConstants.getMonoLabel(),
                decoration: InputDecoration(
                  hintText: 'Search batch code',
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
                    : _errorMessage.isNotEmpty && _allBatches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_errorMessage, style: AppConstants.getBodyMedium(color: AppConstants.error)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadBatches,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                                  child: const Text('Try Again'),
                                )
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
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                            color: isSelected ? Colors.white : AppConstants.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check, color: Colors.white, size: 20),
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
                      'Continue',
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
