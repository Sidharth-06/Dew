import 'dart:io'; // Add this for platform checks
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/main.dart';
import 'package:dew/screens/profile_page.dart';
import 'package:dew/widgets/mini_player.dart';
import 'package:dew/widgets/playlist_cube.dart';
import 'package:dew/widgets/song_artwork.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  User? user;
  String? _profileImageUrl;
  String? _username;
  YoutubePlayerController? _youtubeController;
  bool showVideoPopup = true;
  bool isMuted = false;
  Map<String, dynamic>? trendingVideo;
  bool? aiConsentGiven;
  late Future<List<dynamic>> _playlistsFuture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _fetchUser();
    _fetchUsername();
    _initAnimation();
    _checkAIConsent();
    // Cache playlists so they are not re-fetched on every build
    _playlistsFuture = getPlaylists(playlistsNum: 21);
  }

  Future<void> _fetchUser() async {
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('deviceId');
      if (deviceId == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('profileImage')) {
          setState(() {
            _profileImageUrl = data['profileImage'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    }
  }

  Future<void> _fetchUsername() async {
    if (user == null) return;
    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (userData.exists && mounted) {
        final data = userData.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('username')) {
          setState(() {
            _username = data['username'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
    }
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _fetchTrendingVideo() async {
    try {
      final videoDoc = await FirebaseFirestore.instance
          .collection('trending_videos')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (videoDoc.docs.isNotEmpty && mounted) {
        final videoData = videoDoc.docs.first.data();
        final videoUrl = videoData['videoUrl'] as String?;
        if (videoUrl == null) return;
        final videoId = YoutubePlayer.convertUrlToId(videoUrl);
        if (videoId != null) {
          setState(() {
            trendingVideo = videoData;
            _initYoutubePlayer(videoId);
            showVideoPopup = true;
          });
          _animationController.forward();
        }
      }
    } catch (e) {
      debugPrint('Error fetching trending video: $e');
    }
  }

  void _initYoutubePlayer(String videoId) {
    _youtubeController?.dispose();
    try {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true,
          enableCaption: false,
          loop: true,
          hideControls: true,
          forceHD: false,
          disableDragSeek: true,
        ),
      );
    } catch (e) {
      debugPrint('Error initializing YouTube player: $e');
      setState(() {
        trendingVideo = null;
        showVideoPopup = false;
      });
    }
  }

  void _dismissPopup() {
    _youtubeController?.pause();
    _animationController.reverse().then((_) {
      if (mounted) setState(() => showVideoPopup = false);
    });
  }

  Future<void> _checkAIConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final currentConsent = prefs.getBool('ai_consent');
    if (mounted) {
      setState(() {
        aiConsentGiven = currentConsent;
      });
    }
    if (currentConsent == true) {
      _fetchTrendingVideo();
    } else if (currentConsent == null) {
      final lastShownTimestamp = prefs.getInt('consent_last_shown') ?? 0;
      final lastShownDate =
          DateTime.fromMillisecondsSinceEpoch(lastShownTimestamp);
      final now = DateTime.now();
      if (now.difference(lastShownDate).inDays >= 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAIConsentDialog();
        });
        await prefs.setInt('consent_last_shown', now.millisecondsSinceEpoch);
      }
    }
  }

  Future<void> _showAIConsentDialog() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(FluentIcons.brain_circuit_24_filled,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('AI Music Features'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enable AI-powered features:'),
            const SizedBox(height: 12),
            _buildFeatureItem('Personalized music recommendations'),
            _buildFeatureItem('Latest release suggestions'),
            _buildFeatureItem('Trending music updates'),
            const SizedBox(height: 16),
            Text(
              'We respect your privacy. Your data is used only to enhance your music experience.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () async {
              await prefs.setBool('ai_consent', true);
              if (mounted) {
                setState(() {
                  aiConsentGiven = true;
                });
                _fetchTrendingVideo();
              }
              Navigator.pop(context);
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildCurrentSongBanner(MediaItem? metadata, ThemeData theme) {
    if (metadata == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Song Artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SongArtworkWidget(
              metadata: metadata,
              size: 60,
              errorWidgetIconSize: 30,
              borderRadius: 12,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          // Song Title and Artist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metadata.artist != null)
                  Text(
                    metadata.artist!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: Scrollbar(
        thumbVisibility: Platform.isWindows,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(theme),
            _buildSectionHeader(
                theme, 'Playlist for You..', FluentIcons.list_24_filled),
            _buildPlaylistGrid(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.surface],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAppBarHeader(theme.colorScheme),
                  const SizedBox(height: 20),
                  _buildGreetingMessage(theme),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Row(
          children: [
            Icon(icon, size: 24, color: theme.textTheme.bodyLarge?.color),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid(ThemeData theme) {
    int crossAxisCount = 3;
    double width = MediaQuery.of(context).size.width;
    if (Platform.isWindows) {
      // More columns for wider desktop windows
      if (width > 1200)
        crossAxisCount = 5;
      else if (width > 900) crossAxisCount = 4;
    }
    return FutureBuilder<List<dynamic>>(
      future: _playlistsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerGrid(theme, crossAxisCount);
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            child: Center(
                child: Text('No playlists found.',
                    style: TextStyle(color: theme.colorScheme.error))),
          );
        }
        final playlists = snapshot.data!;
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => MouseRegion(
                cursor: SystemMouseCursors.click,
                child: PlaylistCube(
                  playlists[index],
                  playlistData: playlists[index],
                  onClickOpen: true,
                  showFavoriteButton: false,
                  borderRadius: 13,
                  isAlbum: false,
                ),
              ),
              childCount: playlists.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerGrid(ThemeData theme, int crossAxisCount) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildPlaylistShimmer(theme),
          childCount: crossAxisCount * 2,
        ),
      ),
    );
  }

  Widget _buildPlaylistShimmer(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
              child: Container(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarHeader(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Dew',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontFamily: 'paytoneOne',
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade300,
              backgroundImage:
                  _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(_profileImageUrl!)
                      : const AssetImage('assets/giphy.gif') as ImageProvider,
              onBackgroundImageError:
                  _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? (_, __) {
                          debugPrint(
                              'Error loading profile image: $_profileImageUrl');
                        }
                      : null,
              child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                  ? const Icon(Icons.person, size: 22)
                  : null,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ).then((_) {
              _fetchUser();
              _fetchUsername();
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingMessage(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Text(
        'Good ${_getTimeOfDay()}${_username?.isNotEmpty == true ? ' $_username' : ""}',
        style: theme.textTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: 'roboto',
          fontSize: 28,
          letterSpacing: 0.5,
          shadows: const [
            Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
