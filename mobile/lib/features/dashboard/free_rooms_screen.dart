import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/constants.dart';
import 'package:intl/intl.dart';

class FreeRoomsScreen extends StatefulWidget {
  const FreeRoomsScreen({super.key});

  @override
  State<FreeRoomsScreen> createState() => _FreeRoomsScreenState();
}

class _FreeRoomsScreenState extends State<FreeRoomsScreen> {
  String? _selectedDay;
  String? _selectedTime;
  
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
    final now = DateTime.now();
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
    });

    try {
      final rooms = await ApiService.fetchFreeRooms(_selectedDay!, _selectedTime!);
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to find free rooms. Please try again.';
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
                          value: _selectedDay,
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
                          value: _selectedTime,
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
              child: _searched && !_isLoading
                  ? _rooms.isEmpty
                      ? const Center(
                          child: Text('No free rooms found for this slot.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppConstants.paddingContainer),
                          itemCount: _rooms.length,
                          itemBuilder: (context, index) {
                            final room = _rooms[index];
                            final isLab = (room['type'] as String).toLowerCase().contains('lab');
                            
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: AppConstants.outline),
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
                                subtitle: Text(room['type']),
                              ),
                            );
                          },
                        )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
