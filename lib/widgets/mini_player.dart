import 'package:Dew/widgets/song_artwork.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:Dew/screens/now_playing_page.dart';
import 'package:Dew/widgets/song_artwork.dart';

class MiniPlayer extends StatelessWidget {
  MiniPlayer({super.key, required this.metadata, this.onTap});
  final MediaItem metadata;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, // Adjust the size as needed
        height: 60, // Adjust the size as needed
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.secondaryContainer,
        ),
        child: Center(
          child: ClipOval(
            child: SongArtworkWidget(
              metadata: metadata,
              size: 60, // Adjust the size as needed
              errorWidgetIconSize: 30,
            ),
          ),
        ),
      ),
    );
  }
}
