import 'package:cached_network_image/cached_network_image.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/features/home/presentation/widgets/home_header.dart';
import 'package:dew/features/home/presentation/widgets/section_header.dart';
import 'package:dew/main.dart'; // for audioHandler
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List> _recommendedSongs;
  late Future<List> _playlists;

  @override
  void initState() {
    super.initState();
    // Prefer personalized recommendations when we have user data,
    // otherwise fall back to a trending seed.
    if (userRecentlyPlayed.isNotEmpty || userLikedSongsList.isNotEmpty) {
      _recommendedSongs = getRecommendedSongs(true);
    } else {
      _recommendedSongs = getRecommendedSongs('trending');
    }
    _playlists = getPlaylists(playlistsNum: 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.deepBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeHeader()
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: -0.2, end: 0),
              _buildFeaturedCard()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms)
                  .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack),
              SectionHeader(title: 'For You').animate().fadeIn(delay: 400.ms),
              SizedBox(
                height: 220,
                child: FutureBuilder<List>(
                  future: _recommendedSongs,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuraColors.electricViolet));
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return const SizedBox();
                    }
                    final songs = snapshot.data!;
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: songs.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return _buildSongCard(context, song)
                            .animate(
                                delay: (100 * index).ms) // Staggered animation
                            .fadeIn()
                            .slideX(begin: 0.2, end: 0);
                      },
                    );
                  },
                ),
              ),
              SectionHeader(title: 'Top Playlists')
                  .animate()
                  .fadeIn(delay: 600.ms),
              SizedBox(
                height: 230,
                child: FutureBuilder<List>(
                  future: _playlists,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuraColors.electricViolet));
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return const SizedBox();
                    }
                    final playlists = snapshot.data!;
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: playlists.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return _buildPlaylistCard(context, playlist)
                            .animate(delay: (100 * index).ms)
                            .fadeIn()
                            .slideX(begin: 0.2, end: 0);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard() {
    return Container(
      height: 230,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: AuraColors.primaryGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AuraColors.electricViolet.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative shapes
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -20,
            child: RotationTransition(
              turns: const AlwaysStoppedAnimation(0.1),
              child: Icon(Icons.music_note_rounded,
                  size: 160, color: Colors.white.withOpacity(0.15)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Daily Mix',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        height: 1.0)),
                const SizedBox(height: 8),
                Text('Fresh tracks customized for your vibe.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 14)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    // TODO: Play daily mix
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: AuraColors.electricViolet),
                        SizedBox(width: 8),
                        Text('Play Now',
                            style: TextStyle(
                                color: AuraColors.electricViolet,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSongCard(BuildContext context, Map song) {
    final image = song['highResImage'] ?? song['image'];
    final title = song['title'];
    final artist = song['artist'];

    return GestureDetector(
      onTap: () {
        audioHandler.playSong(song);
      },
      child: Container(
        width: 150,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag:
                  'artwork_${(song['ytid'] ?? song['title'] ?? song.hashCode).toString()}',
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AuraColors.surfaceLight),
                    errorWidget: (_, __, ___) =>
                        Container(color: AuraColors.surfaceLight),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraColors.white,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              artist.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuraColors.white70,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(BuildContext context, Map playlist) {
    final title = playlist['title'];
    final image = playlist['image'];

    return GestureDetector(
      onTap: () {
        // Open Playlist Page
      },
      child: Container(
        width: 150,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AuraColors.surfaceLight,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ]),
                child: image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.album,
                              color: Colors.white24, size: 40),
                        ),
                      )
                    : const Center(
                        child:
                            Icon(Icons.album, color: Colors.white24, size: 40)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraColors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
