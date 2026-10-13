import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/utils.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/timetable/timetable_repository.dart';

import 'ad_banner.dart';
class FreeRoomsScreen extends StatefulWidget {
  const FreeRoomsScreen({super.key});

  @override
  State<FreeRoomsScreen> createState() => _FreeRoomsScreenState();
}

class _FreeRoomsScreenState extends State<FreeRoomsScreen> {
  String? _selectedDay;
  String? _selectedTime;
  
  String? _selectedBlock;
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
    // Default to current day if weekday
    final now = TimeUtils.getKolkataTime();
    if (now.weekday <= 5) {
      _selectedDay = _days[now.weekday - 1];
    } else {
      _selectedDay = _days[0]; // fallback to Monday
    }
    
    // Default to nearest time block
    final hour = now.hour;
    if (hour >= 8 && hour <= 16) {
      _selectedTime = '${hour.toString().padLeft(2, '0')}:30';
    } else {
      _selectedTime = _times[1]; // fallback to 09:30
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
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
      
      // Categorize into blocks using robust block pattern matching
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
      
      // Determine priority block from timetable
      String? priorityBlock;
      
      // Get current local time
      final now = TimeUtils.getKolkataTime();
      final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final todayStr = dayNames[now.weekday - 1];
      
      // Only prioritize if today is a weekday and matches the selected day
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
            final endStr = cls['end_time'] as String? ?? startStr; // fallback if missing
            
            final startParts = startStr.split(':').map(int.parse).toList();
            final startMins = startParts[0] * 60 + startParts[1];
            
            final endParts = endStr.split(':').map(int.parse).toList();
            final endMins = endParts[0] * 60 + endParts[1];
            
            if (currentMinutes >= startMins && currentMinutes <= endMins) {
              runningClass = cls;
              break; // Found running class
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
      
      String? initialBlock = blocks.isNotEmpty ? blocks.first : null;
      if (priorityBlock != null && blocks.contains(priorityBlock)) {
        initialBlock = priorityBlock;
        // Move priority block to front
        blocks.remove(priorityBlock);
        blocks.insert(0, priorityBlock);
      }
      
      setState(() {
        _rooms = rooms;
        _roomsByBlock = blocksMap;
        _availableBlocks = blocks;
        _selectedBlock = initialBlock;
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
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Free Classrooms'),
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
                          decoration: const InputDecoration(
                            labelText: 'Day',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          initialValue: _selectedDay,
                          items: _days.map((day) => DropdownMenuItem(
                            value: day,
                            child: Text(day),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedDay = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          initialValue: _selectedTime,
                          items: _times.map((time) => DropdownMenuItem(
                            value: time,
                            child: Text(time),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedTime = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_selectedDay != null && _selectedTime != null && !_isLoading) 
                          ? _search 
                          : null,
                      icon: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.search),
                      label: Text(_isLoading ? 'Searching...' : 'Find Free Rooms'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                    color: AppConstants.error.withValues(alpha: 0.1),
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
              child: _searched && !_isLoading
                  ? (_rooms.isEmpty && _error.isEmpty)
                      ? const Center(
                          child: Text('No free rooms found for this slot.'),
                        )
                      : _error.isNotEmpty 
                          ? const SizedBox.shrink()
                          : Column(
                          children: [
                            // Horizontal Block Selector
                            SizedBox(
                              height: 50,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                                itemCount: _availableBlocks.length,
                                itemBuilder: (context, index) {
                                  final block = _availableBlocks[index];
                                  final isSelected = _selectedBlock == block;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(block),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() => _selectedBlock = block);
                                        }
                                      },
                                      selectedColor: AppConstants.primary,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : AppConstants.textPrimary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Room List for Selected Block
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(AppConstants.paddingContainer),
                                itemCount: _selectedBlock != null ? _roomsByBlock[_selectedBlock!]?.length ?? 0 : 0,
                                itemBuilder: (context, index) {
                                  final room = _roomsByBlock[_selectedBlock!]![index];
                                  final isLab = (room['type'] as String).toLowerCase().contains('lab');
                                  
                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      side: const BorderSide(color: AppConstants.outline),
                                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isLab 
                                            ? AppConstants.warningContainer 
                                            : AppConstants.primaryContainer,
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
            const AdBanner(),
          ],
        ),
      ),
    );
  }

  /// Categorizes room name into canonical Block (e.g. BL-1 -> Block 1, BL10 -> Block 10, BL11 -> Block 11).
  /// Future-proof for any new university blocks.
  static String extractBlock(String roomName) {
    final upper = roomName.toUpperCase().trim();
    
    // 1. Explicit BL or BLOCK match (e.g. BL-10, BL10, BL-1, BL1, BLOCK-10, BLOCK 10, BLOCK1)
    final blMatch = RegExp(r'(?:BL-?|BLOCK\s*-?)(\d+)', caseSensitive: false).firstMatch(upper);
    if (blMatch != null) {
      final num = int.tryParse(blMatch.group(1)!) ?? blMatch.group(1);
      return 'Block $num';
    }

    // 2. 5-digit room prefix (e.g. 10001, 10101 -> Block 10, 11003 -> Block 11)
    final fiveDigitMatch = RegExp(r'^(\d{2})\d{3}').firstMatch(upper);
    if (fiveDigitMatch != null) {
      final num = int.tryParse(fiveDigitMatch.group(1)!) ?? fiveDigitMatch.group(1);
      return 'Block $num';
    }

    // 3. 4-digit room prefix (e.g. 8003 -> Block 8, 1206 -> Block 1, 2001 -> Block 2)
    final fourDigitMatch = RegExp(r'^(\d)\d{3}').firstMatch(upper);
    if (fourDigitMatch != null) {
      final num = int.tryParse(fourDigitMatch.group(1)!) ?? fourDigitMatch.group(1);
      return 'Block $num';
    }

    // 4. Standalone B tag: e.g. B-10, B10, B-1, B1
    final bMatch = RegExp(r'\bB-?(\d+)\b').firstMatch(upper);
    if (bMatch != null) {
      final num = int.tryParse(bMatch.group(1)!) ?? bMatch.group(1);
      return 'Block $num';
    }

    // 5. Fallback: Any number in string
    final anyDigit = RegExp(r'\d+').firstMatch(upper);
    if (anyDigit != null) {
      final num = int.tryParse(anyDigit.group(0)!) ?? anyDigit.group(0);
      return 'Block $num';
    }

    return 'Other';
  }

  /// Extracts readable floor information from room code.
  /// GF/GL -> Ground Floor, FF/FL -> 1st Floor, SF/SL -> 2nd Floor, TF/TL -> 3rd Floor, 4F -> 4th Floor
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

  /// Natural numerical sorting key for blocks (Block 1, Block 2, Block 3 ... Block 10, Block 11).
  static int blockSortKey(String block) {
    final match = RegExp(r'\d+').firstMatch(block);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 999;
    }
    return 9999;
  }
}
