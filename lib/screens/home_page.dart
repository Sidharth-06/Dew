import 'package:dew/API/musify.dart';
import 'package:dew/main.dart';
import 'package:dew/widgets/home_widgets.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late Future<List> _recommendationsFuture;
  late Future<List> _playlistsFuture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = getRecommendedSongs('trending');
    _playlistsFuture = getPlaylists(playlistsNum: 10);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Start animation after a short delay to allow build
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildAnimatedSection({
    required Widget child,
    required double startTime,
    required double endTime,
  }) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(startTime, endTime, curve: Curves.easeOutQuart),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.15),
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeHeader(),

                // Recently Played Grid
                _buildAnimatedSection(
                  startTime: 0.0,
                  endTime: 0.4,
                  child: ValueListenableBuilder(
                    valueListenable: currentRecentlyPlayedLength,
                    builder: (context, value, child) {
                      if (userRecentlyPlayed.isEmpty)
                        return const SizedBox.shrink();

                      // Take top 6 for the grid
                      final recentItems = userRecentlyPlayed.take(6).toList();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 3, // Wide rectangular cards
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: recentItems.length,
                          itemBuilder: (context, index) {
                            final item = recentItems[index];
                            return RecentGridItem(
                              item: Map<String, dynamic>.from(item),
                              onTap: () {
                                audioHandler.playSong(item);
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Made For You Section
                _buildAnimatedSection(
                  startTime: 0.2,
                  endTime: 0.6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Made For You'),
                      SizedBox(
                        height: 200, // Increased height to prevent overflow
                        child: FutureBuilder<List>(
                          future: _recommendationsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final songs = snapshot.data ?? [];
                            if (songs.isEmpty) {
                              return const Center(
                                  child: Text('No recommendations yet'));
                            }
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: songs.length,
                              itemBuilder: (context, index) {
                                final song = songs[index];
                                return HorizontalCard(
                                  item: Map<String, dynamic>.from(song),
                                  onTap: () {
                                    audioHandler.playSong(song);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Popular Playlists Section
                _buildAnimatedSection(
                  startTime: 0.4,
                  endTime: 0.8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Popular Playlists'),
                      SizedBox(
                        height: 200, // Increased height
                        child: FutureBuilder<List>(
                          future: _playlistsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final playlists = snapshot.data ?? [];
                            if (playlists.isEmpty) {
                              return const Center(
                                  child: Text('No playlists found'));
                            }
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: playlists.length,
                              itemBuilder: (context, index) {
                                final playlist = playlists[index];
                                return HorizontalCard(
                                  item: Map<String, dynamic>.from(playlist),
                                  isPlaylist: true,
                                  onTap: () {
                                    // Handle playlist tap
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 100), // Bottom padding for mini player
              ],
            ),
          ),
        ),
      ),
    );
  }
}
