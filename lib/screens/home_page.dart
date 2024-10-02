import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:Dew/API/musify.dart';
import 'package:Dew/extensions/l10n.dart';
import 'package:Dew/main.dart';
import 'package:Dew/screens/playlist_page.dart';
import 'package:Dew/services/router_service.dart';
import 'package:Dew/widgets/like_button.dart';
import 'package:Dew/widgets/no_artwork_cube.dart';
import 'package:Dew/widgets/playlist_cube.dart';
import 'package:Dew/widgets/spinner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildCustomAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopNavBar(context),
            const SizedBox(height: 20),
            _buildAllPlaylists(),
          ],
        ),
      ),
    );
  }

  AppBar _buildCustomAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Dew',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 28,
              fontFamily: 'paytoneOne',
              fontWeight: FontWeight.bold,
            ),
          ),
         
        ],
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: SizedBox(
        height: 100, // Adjust the height as needed
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildNavButton(
              icon: const Icon(FluentIcons.history_24_filled, size: 30),
              label: context.l10n!.recentlyPlayed,
              onPressed: () =>
                  NavigationManager.router.go('/home/userSongs/recents'),
            ),
            
            const SizedBox(width: 10),
            _buildNavButton(
              icon: const Icon(FluentIcons.music_note_2_24_regular, size: 30),
              label: context.l10n!.likedSongs,
              onPressed: () =>
                  NavigationManager.router.go('/home/userSongs/liked'),
            ),
            const SizedBox(width: 10),
            _buildNavButton(
              icon: const Icon(FluentIcons.task_list_ltr_24_regular, size: 30),
              label: context.l10n!.likedPlaylists,
              onPressed: () =>
                  NavigationManager.router.go('/home/userLikedPlaylists'),
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required Icon icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: icon,
          onPressed: onPressed,
          splashRadius: 30,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAllPlaylists() {
    return FutureBuilder<List<dynamic>>(
      future: getPlaylists(playlistsNum: 21), // Fetch a sufficient number of playlists
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        } else if (snapshot.hasError) {
          logger.log(
            'Error in _buildAllPlaylists',
            snapshot.error,
            snapshot.stackTrace,
          );
          return _buildErrorWidget(context);
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildPlaylistSection(context, snapshot.data!);
      },
    );
  }

Widget _buildPlaylistSection(BuildContext context, List<dynamic> playlists) {
  return Padding(
    padding: const EdgeInsets.all(15.0), // Padding around the grid
    child: GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Number of items per row
        crossAxisSpacing: 12, // Spacing between items horizontally
        mainAxisSpacing: 12, // Spacing between items vertically
        childAspectRatio: 0.65, // Adjust aspect ratio to make items fit well
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return PlaylistCube(
          playlist,
          playlistData: playlist,
          onClickOpen: true,
          showFavoriteButton: false,
          size: 240, // Adjust size if needed
          borderRadius: 13,
          isAlbum: false,
        );
      },
    ),
  );
}



  Widget _buildLoadingWidget() {
    return const Center(
      child: Spinner(),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Text(
        context.l10n!.error,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
