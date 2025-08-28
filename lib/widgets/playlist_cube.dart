import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/extensions/l10n.dart';
import 'package:dew/screens/playlist_page.dart';
import 'package:dew/widgets/like_button.dart';
import 'package:dew/widgets/no_artwork_cube.dart';

class PlaylistCube extends StatelessWidget {
  PlaylistCube(
    this.playlist, {
    super.key,
    this.playlistData,
    this.onClickOpen = true,
    this.showFavoriteButton = true,
    this.cubeIcon = FluentIcons.music_note_1_24_regular,
    this.size = 220,
    this.borderRadius = 13,
    this.isAlbum = false,
  }) : playlistLikeStatus = ValueNotifier<bool>(
          isPlaylistAlreadyLiked(playlist['ytid']), // Optimized lookup
        );

  final Map? playlistData;
  final Map playlist;
  final bool onClickOpen;
  final bool showFavoriteButton;
  final IconData cubeIcon;
  final double size;
  final double borderRadius;
  final bool? isAlbum;

  static const double _paddingValue = 4.0; // Explicitly double
  static const double _likeButtonOffset = 5.0;
  static const double _iconSizeNullArtwork = 30.0;
  static const double _albumTextFontSize = 12.0;

  final ValueNotifier<bool> playlistLikeStatus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color secondaryColor = colorScheme.secondary;
    final Color onSecondaryColor = colorScheme.onSecondary;

    // Cache frequently accessed playlist properties
    final String? playlistYtid = playlist['ytid']?.toString();
    final String? imageUrl = playlist['image']?.toString();
    final String playlistTitle =
        playlist['title']?.toString() ?? 'Unknown';

    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onClickOpen && (playlistYtid != null || playlistData != null)
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaylistPage(
                        playlistId: playlistYtid,
                        playlistData: playlistData,
                      ),
                    ),
                  );
                }
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? CachedNetworkImage(
                    key: ValueKey<String>(playlistYtid ??
                        imageUrl), // Use ytid if available, else imageUrl
                    height: size,
                    width: size,
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: size,
                      width: size,
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      // It's good practice to log this error for debugging
                      // logger.log('Failed to load image: $url', error, StackTrace.current);
                      print(
                          'PlaylistCube: Failed to load image: $url, Error: $error');
                      return NullArtworkWidget(
                        icon: cubeIcon,
                        iconSize: _iconSizeNullArtwork,
                        size: size,
                        title: playlistTitle,
                      );
                    },
                  )
                : NullArtworkWidget(
                    icon: cubeIcon,
                    iconSize: _iconSizeNullArtwork,
                    size: size,
                    title: playlistTitle,
                  ),
          ),
        ),
        if (playlistYtid != null &&
            playlistYtid.isNotEmpty &&
            showFavoriteButton)
          Positioned(
            bottom: _likeButtonOffset,
            right: _likeButtonOffset,
            child: ValueListenableBuilder<bool>(
              valueListenable: playlistLikeStatus,
              builder: (_, isLiked, __) {
                return LikeButton(
                  // Assuming LikeButton is efficient
                  onPrimaryColor: onSecondaryColor,
                  onSecondaryColor: secondaryColor,
                  isLiked: isLiked,
                  onPressed: () {
                    final newValue = !playlistLikeStatus.value;
                    playlistLikeStatus.value = newValue;
                    updatePlaylistLikeStatus(playlistYtid! as Map, newValue);
                    // currentLikedPlaylistsLength is updated within updatePlaylistLikeStatus
                  },
                );
              },
            ),
          ),
        if (isAlbum ?? false)
          Positioned(
            top: _likeButtonOffset,
            right: _likeButtonOffset,
            child: Container(
              decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.85), // Adjusted opacity
                  borderRadius: BorderRadius.circular(_paddingValue),
                  boxShadow: const [
                    // Subtle shadow for better visibility
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2.0,
                      offset: Offset(0, 1),
                    )
                  ]),
              padding: const EdgeInsets.symmetric(
                  horizontal: _paddingValue * 1.5,
                  vertical: _paddingValue * 0.75),
              child: Text(
                context.l10n?.album ?? 'Album',
                style: TextStyle(
                  color: onSecondaryColor,
                  fontSize: _albumTextFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
