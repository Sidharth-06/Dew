import 'package:dew/main.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dew/screens/now_playing_page.dart';
import 'package:dew/widgets/song_artwork.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer(MediaItem? metadata, ThemeData theme, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaItem = audioHandler.mediaItem.value;

    if (mediaItem == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _navigateToNowPlaying(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.8),
              theme.colorScheme.secondary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Song Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SongArtworkWidget(
                metadata: mediaItem,
                size: 50,
                errorWidgetIconSize: 25,
                borderRadius: 12,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            // Song Title and Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mediaItem.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (mediaItem.artist != null)
                    Text(
                      mediaItem.artist!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Play/Pause Button
            StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data?.playing ?? false;
                return IconButton(
                  icon: Icon(
                    isPlaying
                        ? FluentIcons.pause_24_filled
                        : FluentIcons.play_24_filled,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (isPlaying) {
                      audioHandler.pause();
                    } else {
                      audioHandler.play();
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToNowPlaying(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NowPlayingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
