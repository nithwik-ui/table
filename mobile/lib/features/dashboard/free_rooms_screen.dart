import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/utils.dart';
import '../../core/constants.dart';
import '../../core/theme_controller.dart';
import '../../core/storage.dart';
import '../../core/timetable/timetable_repository.dart';

class FreeRoomsScreen extends StatefulWidget {
  const FreeRoomsScreen({super.key});

  @override
  State<FreeRoomsScreen> createState() => _FreeRoomsScreenState();
}

class _FreeRoomsScreenState extends State<FreeRoomsScreen> {
  String? _selectedDay;
  String? _selectedTime;
  
  String? _selectedBlock; // null or 'All' means All Blocks grouped view
  Map<String, List<dynamic>> _roomsByBlock = {};
  List<String> _availableBlocks = [];
  
  bool _isLoading = false;
  String _error = '';
  List<dynamic> _rooms = [];
  bool _searched = false;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  final List<String> _times = [
    '08:30', '09:30', '10:30', '11:30', '12:30', '13:30', '14:30', '15:30', '16:30'
  ];

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    final now = TimeUtils.getKolkataTime();
    if (now.weekday <= 5) {
      _selectedDay = _days[now.weekday - 1];
    } else {
      _selectedDay = _days[0];
    }
    
    final hour = now.hour;
    if (hour >= 8 && hour <= 16) {
      _selectedTime = '${hour.toString().padLeft(2, '0')}:30';
    } else {
      _selectedTime = _times[1];
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _search() async {
    if (_selectedDay == null || _selectedTime == null) return;
    
    setState(() {
      _isLoading = true;
      _error = '';
      _searched = true;
      _availableBlocks = [];
      _roomsByBlock = {};
    });

    try {
      final rooms = await ApiService.fetchFreeRooms(_selectedDay!, _selectedTime!);
      
      Map<String, List<dynamic>> blocksMap = {};
      for (final room in rooms) {
        final name = (room['name'] as String? ?? '').trim();
        final block = extractBlock(name);
        
        if (!blocksMap.containsKey(block)) {
          blocksMap[block] = [];
        }
        blocksMap[block]!.add(room);
      }
      
      final blocks = blocksMap.keys.toList()
        ..sort((a, b) => blockSortKey(a).compareTo(blockSortKey(b)));
      
      String? priorityBlock;
      final now = TimeUtils.getKolkataTime();
      final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final todayStr = dayNames[now.weekday - 1];
      
      if (todayStr == _selectedDay) {
        List<dynamic> classes = TimetableRepository.instance.getClassesForDay(todayStr);
        if (classes.isEmpty) {
          final cached = StorageService.getTimetableCache();
          final dayData = cached.firstWhere(
            (e) => (e['day'] as String?)?.toLowerCase() == todayStr.toLowerCase(),
            orElse: () => null,
          );
          if (dayData != null && dayData['classes'] is List) {
            classes = dayData['classes'] as List<dynamic>;
          }
        }

        if (classes.isNotEmpty) {
          final currentMinutes = now.hour * 60 + now.minute;
          Map<String, dynamic>? runningClass;
          Map<String, dynamic>? lastCompletedClass;
          Map<String, dynamic>? nearestUpcomingClass;
          int minUpcomingDiff = 9999;
          int minCompletedDiff = 9999;
          
          for (final cls in classes) {
            final startStr = cls['start_time'] as String;
            final endStr = cls['end_time'] as String? ?? startStr;
            
            final startParts = startStr.split(':').map(int.parse).toList();
            final startMins = startParts[0] * 60 + startParts[1];
            
            final endParts = endStr.split(':').map(int.parse).toList();
            final endMins = endParts[0] * 60 + endParts[1];
            
            if (currentMinutes >= startMins && currentMinutes <= endMins) {
              runningClass = cls;
              break;
            } else if (currentMinutes > endMins) {
              final diff = currentMinutes - endMins;
              if (diff < minCompletedDiff) {
                minCompletedDiff = diff;
                lastCompletedClass = cls;
              }
            } else if (currentMinutes < startMins) {
              final diff = startMins - currentMinutes;
              if (diff < minUpcomingDiff) {
                minUpcomingDiff = diff;
                nearestUpcomingClass = cls;
              }
            }
          }
          
          final targetClass = runningClass ?? lastCompletedClass ?? nearestUpcomingClass;
          if (targetClass != null) {
            final roomStr = targetClass['room'] as String? ?? '';
            final b = extractBlock(roomStr);
            if (b != 'Other') {
              priorityBlock = b;
            }
          }
        }
      }
      
      if (priorityBlock != null && blocks.contains(priorityBlock)) {
        blocks.remove(priorityBlock);
        blocks.insert(0, priorityBlock);
      }
      
      setState(() {
        _rooms = rooms;
        _roomsByBlock = blocksMap;
        _availableBlocks = blocks;
        _selectedBlock = 'All';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is FreeRoomsException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedSlotTime = _selectedTime != null ? TimeUtils.format12Hour(_selectedTime!) : 'Now';

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FREE CLASSROOMS',
              style: AppConstants.getHeadline().copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              '${_selectedDay ?? 'Today'} · $formattedSlotTime',
              style: AppConstants.getLabelSmall(color: AppConstants.textSecondary).copyWith(fontSize: 11.5),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: AppConstants.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Form
            Container(
              color: AppConstants.surface,
              padding: const EdgeInsets.all(AppConstants.paddingContainer),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Day',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          dropdownColor: AppConstants.surfaceElevated,
                          style: AppConstants.getBodyMedium(),
                          initialValue: _selectedDay,
                          items: _days.map((day) => DropdownMenuItem(
                            value: day,
                            child: Text(day, style: AppConstants.getBodyMedium()),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedDay = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          dropdownColor: AppConstants.surfaceElevated,
                          style: AppConstants.getBodyMedium(),
                          initialValue: _selectedTime,
                          items: _times.map((time) => DropdownMenuItem(
                            value: time,
                            child: Text(TimeUtils.format12Hour(time), style: AppConstants.getBodyMedium()),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedTime = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_selectedDay != null && _selectedTime != null && !_isLoading) 
                          ? _search 
                          : null,
                      icon: _isLoading 
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.onPrimary),
                            ) 
                          : const Icon(Icons.search, size: 18),
                      label: Text(_isLoading ? 'Searching...' : 'Find Free Rooms'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primary,
                        foregroundColor: AppConstants.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppConstants.paddingContainer),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppConstants.error),
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
              child: _searched && !_isLoading
                  ? (_rooms.isEmpty && _error.isEmpty)
                      ? Center(
                          child: Text(
                            'No free rooms found for this slot.',
                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                          ),
                        )
                      : _error.isNotEmpty 
                          ? const SizedBox.shrink()
                          : Column(
                              children: [
                                // Horizontal Block Selector (All + Individual Blocks)
                                SizedBox(
                                  height: 52,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 6),
                                    itemCount: _availableBlocks.length + 1,
                                    itemBuilder: (context, index) {
                                      final block = index == 0 ? 'All' : _availableBlocks[index - 1];
                                      final isSelected = (_selectedBlock ?? 'All') == block;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text(block == 'All' ? 'All Blocks' : block),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() => _selectedBlock = block);
                                            }
                                          },
                                          selectedColor: AppConstants.primary,
                                          backgroundColor: AppConstants.surface,
                                          side: BorderSide(
                                            color: isSelected ? AppConstants.primary : AppConstants.outline,
                                          ),
                                          labelStyle: TextStyle(
                                            color: isSelected ? AppConstants.onPrimary : AppConstants.textPrimary,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Room List (Grouped by Block when 'All' is selected, or filtered to 1 Block)
                                Expanded(
                                  child: (_selectedBlock == null || _selectedBlock == 'All')
                                      ? ListView.builder(
                                          padding: const EdgeInsets.all(AppConstants.paddingContainer),
                                          itemCount: _availableBlocks.length,
                                          itemBuilder: (context, blockIdx) {
                                            final blockName = _availableBlocks[blockIdx];
                                            final blockRooms = _roomsByBlock[blockName] ?? [];
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 14),
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: AppConstants.surface,
                                                borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                                border: Border.all(color: AppConstants.outline),
                                                boxShadow: AppConstants.shadowLevel1,
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        blockName,
                                                        style: AppConstants.getHeadline().copyWith(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${blockRooms.length} free',
                                                        style: AppConstants.getLabelSmall(color: AppConstants.successText).copyWith(
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: blockRooms.map((r) {
                                                      final roomName = r['name']?.toString() ?? '';
                                                      final isLab = (r['type']?.toString() ?? '').toLowerCase().contains('lab');
                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: isLab ? AppConstants.warningContainer : AppConstants.background,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: isLab
                                                                ? AppConstants.warning.withValues(alpha: 0.4)
                                                                : AppConstants.outline,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          roomName,
                                                          style: AppConstants.getMonoLabel(
                                                            color: isLab ? AppConstants.warningText : AppConstants.textPrimary,
                                                          ).copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(AppConstants.paddingContainer),
                                          itemCount: _roomsByBlock[_selectedBlock!]?.length ?? 0,
                                          itemBuilder: (context, index) {
                                            final room = _roomsByBlock[_selectedBlock!]![index];
                                            final isLab = (room['type'] as String).toLowerCase().contains('lab');
                                            
                                            return Card(
                                              elevation: 0,
                                              color: AppConstants.surface,
                                              margin: const EdgeInsets.only(bottom: 8),
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(color: AppConstants.outline),
                                                borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                              ),
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor: isLab 
                                                      ? AppConstants.warningContainer 
                                                      : AppConstants.secondaryContainer,
                                                  child: Icon(
                                                    isLab ? Icons.computer : Icons.room_preferences,
                                                    color: isLab ? AppConstants.warning : AppConstants.primary,
                                                  ),
                                                ),
                                                title: Text(
                                                  room['name'],
                                                  style: AppConstants.getHeadline().copyWith(fontSize: 16),
                                                ),
                                                subtitle: Text(
                                                  extractFloor(room['name']) != null
                                                      ? '${room['type']} • ${extractFloor(room['name'])}'
                                                      : room['type'],
                                                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Categorizes room name into canonical Block (e.g. BL-1 -> Block 1, BL10 -> Block 10, BL11 -> Block 11).
  static String extractBlock(String roomName) {
    final upper = roomName.toUpperCase().trim();
    
    final blMatch = RegExp(r'(?:BL-?|BLOCK\s*-?)(\d+)', caseSensitive: false).firstMatch(upper);
    if (blMatch != null) {
      final num = int.tryParse(blMatch.group(1)!) ?? blMatch.group(1);
      return 'Block $num';
    }

    final fiveDigitMatch = RegExp(r'^(\d{2})\d{3}').firstMatch(upper);
    if (fiveDigitMatch != null) {
      final num = int.tryParse(fiveDigitMatch.group(1)!) ?? fiveDigitMatch.group(1);
      return 'Block $num';
    }

    final fourDigitMatch = RegExp(r'^(\d)\d{3}').firstMatch(upper);
    if (fourDigitMatch != null) {
      final num = int.tryParse(fourDigitMatch.group(1)!) ?? fourDigitMatch.group(1);
      return 'Block $num';
    }

    final bMatch = RegExp(r'\bB-?(\d+)\b').firstMatch(upper);
    if (bMatch != null) {
      final num = int.tryParse(bMatch.group(1)!) ?? bMatch.group(1);
      return 'Block $num';
    }

    final anyDigit = RegExp(r'\d+').firstMatch(upper);
    if (anyDigit != null) {
      final num = int.tryParse(anyDigit.group(0)!) ?? anyDigit.group(0);
      return 'Block $num';
    }

    return 'Other';
  }

  static String? extractFloor(String roomName) {
    final upper = roomName.toUpperCase();
    if (upper.contains('-GF') || upper.contains('_GF') || upper.contains('-GL') || upper.contains('_GL')) {
      return 'Ground Floor';
    }
    if (upper.contains('-FF') || upper.contains('_FF') || upper.contains('-FL') || upper.contains('_FL')) {
      return '1st Floor';
    }
    if (upper.contains('-SF') || upper.contains('_SF') || upper.contains('-SL') || upper.contains('_SL')) {
      return '2nd Floor';
    }
    if (upper.contains('-TF') || upper.contains('_TF') || upper.contains('-TL') || upper.contains('_TL')) {
      return '3rd Floor';
    }
    if (upper.contains('-4F') || upper.contains('_4F') || upper.contains('-4L') || upper.contains('_4L')) {
      return '4th Floor';
    }
    return null;
  }

  static int blockSortKey(String block) {
    final match = RegExp(r'\d+').firstMatch(block);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 999;
    }
    return 9999;
  }
}
