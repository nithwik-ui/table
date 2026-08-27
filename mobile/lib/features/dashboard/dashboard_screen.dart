import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import 'home_tab.dart';
import 'week_tab.dart';
import 'changes_tab.dart';
import 'profile_tab.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTab;

  const DashboardScreen({super.key, this.initialTab = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentIndex;
  bool _hasUnreadChanges = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _checkForChanges();
  }

  void _checkForChanges() async {
    final selection = StorageService.getSelection();
    if (selection == null) return;
    final batchId = selection['batchId']!;

    try {
      final list = await ApiService.fetchChanges(batchId);
      if (list.isNotEmpty) {
        // Compare with cached changes count to see if there is something new
        final cachedCount = StorageService.getChangesCache().length;
        if (list.length > cachedCount) {
          setState(() {
            _hasUnreadChanges = true;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Peer tab views
    final tabs = [
      const HomeTab(),
      const WeekTab(),
      const ChangesTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppConstants.outline, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (index == 2) {
                // Opened Changes tab - remove the red dot
                _hasUnreadChanges = false;
              }
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppConstants.surface,
          selectedItemColor: AppConstants.primary,
          unselectedItemColor: AppConstants.textSecondary,
          selectedLabelStyle: AppConstants.getLabelSmall(color: AppConstants.primary).copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_view_week_outlined),
              activeIcon: Icon(Icons.calendar_view_week),
              label: 'Week',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.history_outlined),
                  if (_hasUnreadChanges)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppConstants.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.history),
              label: 'Changes',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
