import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../free_rooms_screen.dart';
import '../changes_tab.dart';

/// Shared top app bar used across all main tabs.
/// Shows logo on left, and Free Rooms / Changes / Notifications icons on right.
/// Free Rooms icon is Student-only.
class SruAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool hasUnreadChanges;
  final VoidCallback? onChangesTapped;

  const SruAppBar({
    super.key,
    this.hasUnreadChanges = false,
    this.onChangesTapped,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 12),
              // Logo
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/logo.png',
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Free Rooms (For both Student and Faculty)
              _AppBarIconButton(
                icon: Icons.door_front_door_outlined,
                tooltip: 'Free Classrooms',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FreeRoomsScreen()),
                ),
              ),
              // Changes
              _AppBarIconButton(
                icon: Icons.history_outlined,
                tooltip: 'Changes',
                hasIndicator: hasUnreadChanges,
                onPressed: () {
                  onChangesTapped?.call();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangesScreen()),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool hasIndicator;

  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.hasIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppConstants.textPrimary, size: 24),
              if (hasIndicator)
                Positioned(
                  right: 8,
                  top: 8,
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
        ),
      ),
    );
  }
}
