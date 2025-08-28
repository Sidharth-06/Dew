import 'package:dew/screens/now_playing_page.dart';
import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:dew/extensions/l10n.dart';
import 'package:dew/main.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:dew/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({
    super.key,
    required this.child,
  });

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage>
    with SingleTickerProviderStateMixin {
  final _selectedIndex = ValueNotifier<int>(0);
  final iconList = <IconData>[
    FluentIcons.home_24_regular,
    FluentIcons.search_24_regular,
    FluentIcons.book_24_regular,
    FluentIcons.settings_24_regular,
  ];

  late final AnimationController _notchAndCornersAnimationController =
      AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );

  @override
  void dispose() {
    _notchAndCornersAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          widget.child,

          // Floating mini player overlay
          StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, snapshot) {
              final hasMedia = snapshot.hasData && snapshot.data != null;
              if (!hasMedia) return const SizedBox.shrink();

              return Positioned(
                bottom: 100, // Position above bottom nav
                left: 0,
                right: 0,
                child: MiniPlayer(
                  snapshot.data, // Pass the MediaItem metadata
                  Theme.of(context), // Pass the current theme
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNavigationBar(
        icons: iconList,
        activeIndex: _selectedIndex.value,
        backgroundColor: Theme.of(context).colorScheme.surface,
        inactiveColor: Theme.of(context).colorScheme.onSurface,
        activeColor: Colors.green,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        leftCornerRadius: 32,
        rightCornerRadius: 32,
        onTap: (index) {
          widget.child.goBranch(
            index,
            initialLocation: index == widget.child.currentIndex,
          );
          setState(() {
            _selectedIndex.value = index;
          });
        },
      ),
    );
  }
}
