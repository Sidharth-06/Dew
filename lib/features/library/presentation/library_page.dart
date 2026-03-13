import 'package:cached_network_image/cached_network_image.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/main.dart'; // audioHandler
import 'package:flutter/material.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AuraColors.deepBlack,
        appBar: AppBar(
          backgroundColor: AuraColors.deepBlack,
          title: Text(
            'Your Library',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          bottom: const TabBar(
            indicatorColor: AuraColors.electricViolet,
            labelColor: AuraColors.electricViolet,
            unselectedLabelColor: Colors.white54,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: 'Playlists'),
              Tab(text: 'Liked Songs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PlaylistsTab(),
            LikedSongsTab(),
          ],
        ),
      ),
    );
  }
}

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentLikedPlaylistsLength,
      builder: (context, length, _) {
        if (length == 0) {
          return const Center(
              child: Text('No playlists yet',
                  style: TextStyle(color: Colors.white54)));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: length,
          itemBuilder: (context, index) {
            final playlist = userLikedPlaylists[index];
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AuraColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: playlist['image'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: playlist['image'],
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.music_note,
                              color: Colors.white54),
                        ),
                      )
                    : const Icon(Icons.music_note, color: Colors.white54),
              ),
              title: Text(playlist['title'] ?? 'Unknown',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('${playlist['list']?.length ?? 0} songs',
                  style: const TextStyle(color: Colors.white54)),
              onTap: () {
                // TODO: Open playlist view details
              },
            );
          },
        );
      },
    );
  }
}

class LikedSongsTab extends StatelessWidget {
  const LikedSongsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentLikedSongsLength,
      builder: (context, length, _) {
        if (length == 0) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 60, color: Colors.white24),
                SizedBox(height: 16),
                Text('No liked songs yet',
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: length,
          itemBuilder: (context, index) {
            // Reverse order to show newest first
            final song = userLikedSongsList[length - 1 - index];
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: song['image'].toString(),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: AuraColors.surfaceLight),
                ),
              ),
              title: Text(
                song['title'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                song['artist'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.favorite,
                    color: AuraColors.electricViolet),
                onPressed: () {
                  updateSongLikeStatus(song['ytid'], false);
                },
              ),
              onTap: () {
                audioHandler.playSong(song);
              },
            );
          },
        );
      },
    );
  }
}
