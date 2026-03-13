import 'package:dew/features/player/presentation/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/core/widgets/glass_container.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Important for glass effect
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return GlassContainer(
      height: 85,
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      borderRadius: BorderRadius.circular(24),
      color: AuraColors.almostBlack,
      opacity: 0.8,
      blur: 20,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
              context, 0, Icons.home_rounded, Icons.home_outlined, 'Home'),
          _buildNavItem(context, 1, Icons.search_rounded, Icons.search_outlined,
              'Search'),
          _buildNavItem(context, 2, Icons.library_music_rounded,
              Icons.library_music_outlined, 'Library'),
          _buildNavItem(context, 3, Icons.person_rounded, Icons.person_outlined,
              'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData selectedIcon,
      IconData unselectedIcon, String label) {
    final isSelected = navigationShell.currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? selectedIcon : unselectedIcon,
            color: isSelected ? AuraColors.electricViolet : AuraColors.white38,
            size: 26,
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AuraColors.electricViolet,
                shape: BoxShape.circle,
              ),
            )
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
