import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:Dew/extensions/l10n.dart';
import 'package:Dew/main.dart';
import 'package:Dew/services/settings_manager.dart';
import 'package:Dew/widgets/mini_player.dart';
import 'package:Dew/screens/now_playing_page.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({
    super.key,
    required this.child,
  });

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  final _selectedIndex = ValueNotifier<int>(0);
  final iconList = <IconData>[
    FluentIcons.home_24_regular,
    FluentIcons.search_24_regular,
    FluentIcons.book_24_regular,
    FluentIcons.settings_24_regular,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      floatingActionButton: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          return AnimatedOpacity(
            opacity: snapshot.hasData
                ? 1.0
                : 0.0, // Fade in/out based on whether media is playing
            duration: const Duration(
                milliseconds: 300), // Duration for smooth fade-in
            child: snapshot.hasData
                ? FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NowPlayingPage(), // Directly push NowPlayingPage
                        ),
                      );
                    },
                    child: MiniPlayer(
                      metadata: snapshot.data!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NowPlayingPage(), // Directly push NowPlayingPage
                          ),
                        );
                      },
                    ),
                    backgroundColor: Colors
                        .transparent, // Ensure the background is transparent
                    elevation: 0, // Remove elevation for a flat appearance
                  )
                : SizedBox.shrink(), // Hide FAB when no music is playing
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
