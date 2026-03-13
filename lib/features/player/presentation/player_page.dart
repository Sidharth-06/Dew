import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dew/API/musify.dart' as musify;
import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/features/player/logic/lyrics_helper.dart';
import 'package:dew/features/player/logic/player_provider.dart';
import 'package:dew/main.dart';
import 'package:dew/services/lyrics_manager.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const double _artworkSize = 340;
  static const Duration _meshDuration = Duration(seconds: 18);
  static const List<int> _sleepTimerOptions = [15, 30, 45, 60];
  static const Duration _sleepTickInterval = Duration(seconds: 30);

  late AnimationController _meshController;
  bool _isShuffleEnabled = false;
  // State to track if video is in full-background mode (true) or card mode (false)
  bool _isBackgroundVideoMode = false;
  // GlobalKey to persist VideoPlayer state across parent widget changes and prevent texture flickering
  final GlobalKey _videoPlayerKey = GlobalKey();
  LoopMode _repeatMode = LoopMode.off;
  Timer? _sleepTimer;
  Timer? _sleepTickTimer;
  DateTime? _sleepEndTime;
  int? _lastSleepRemainingMinutes;
  Duration? _sleepTimerRemaining;
  bool _isDownloading = false;
  bool _showLyrics = false;
  Future<LyricsReaderModel>? _lyricsFuture;
  final Set<String> _offlineSongs = {};
  final ValueNotifier<List<Map<String, dynamic>>> _customPlaylists =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  // Track current song ID to avoid stale lyrics
  String? _currentLyricsSongId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Force immersive mode for full screen experience
    // Force immersive mode and transparent bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    _meshController = AnimationController(
      vsync: this,
      duration: _meshDuration,
    );
    _initAudioState();
    _startMeshAnimation();
  }

  void _initAudioState() {
    if (!audioHandlerInitialized) return;
    _isShuffleEnabled = audioHandler.audioPlayer.shuffleModeEnabled;
    _repeatMode = audioHandler.audioPlayer.loopMode;
  }

  void _startMeshAnimation() {
    final state = ref.read(playerProvider);
    if (!state.isVideoInitialized && mounted) {
      _meshController.repeat();
    }
  }

  void _stopMeshAnimation() {
    _meshController.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    ref.read(playerProvider.notifier).setIsAppResumed(
          state == AppLifecycleState.resumed,
        );
    if (state == AppLifecycleState.paused) {
      _stopMeshAnimation();
    } else if (state == AppLifecycleState.resumed) {
      _startMeshAnimation();
    }
  }

  // --- Controls Logic ---
  void _toggleShuffle() {
    setState(() {
      _isShuffleEnabled = !_isShuffleEnabled;
    });
    audioHandler.setShuffleMode(
      _isShuffleEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  void _cycleRepeatMode() {
    setState(() {
      switch (_repeatMode) {
        case LoopMode.off:
          _repeatMode = LoopMode.one;
          break;
        case LoopMode.one:
          _repeatMode = LoopMode.all;
          break;
        case LoopMode.all:
          _repeatMode = LoopMode.off;
          break;
      }
    });
    audioHandler.audioPlayer.setLoopMode(_repeatMode);
  }

  IconData _getRepeatIcon() {
    switch (_repeatMode) {
      case LoopMode.one:
        return Icons.repeat_one_rounded;
      case LoopMode.all:
        return Icons.repeat_on_rounded;
      default:
        return Icons.repeat_rounded;
    }
  }

  Color _getRepeatColor() {
    return _repeatMode != LoopMode.off
        ? AuraColors.electricViolet
        : Colors.white70;
  }

  // --- Sleep Timer ---
  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AuraColors.deepBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sleep Timer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (_sleepTimer != null) ...[
              ListTile(
                leading: const Icon(Icons.timer_off_rounded,
                    color: Colors.redAccent),
                title: const Text('Cancel Timer',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Remaining: ${_sleepTimerRemaining?.inMinutes ?? 0} min',
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  _cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
            ],
            ..._sleepTimerOptions.map((minutes) => ListTile(
                  leading:
                      const Icon(Icons.timer_rounded, color: Colors.white70),
                  title: Text('$minutes minutes',
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    _setSleepTimer(Duration(minutes: minutes));
                    Navigator.pop(context);
                  },
                )),
            ListTile(
              leading:
                  const Icon(Icons.music_note_rounded, color: Colors.white70),
              title: const Text('End of current song',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                final currentMedia = audioHandler.mediaItem.value;
                final currentPos = audioHandler.audioPlayer.position;
                final duration = currentMedia?.duration ?? Duration.zero;
                final remaining = duration - currentPos;
                if (remaining > Duration.zero) {
                  _setSleepTimer(remaining);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setSleepTimer(Duration duration) {
    _cancelSleepTimer();
    _sleepTimerRemaining = duration;
    _sleepEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      audioHandler.pause();
      _sleepTimer = null;
      _sleepTimerRemaining = null;
      _sleepEndTime = null;
      _sleepTickTimer?.cancel();
      if (mounted) setState(() {});
    });

    _sleepTickTimer?.cancel();
    _sleepTickTimer = Timer.periodic(_sleepTickInterval, (timer) {
      if (_sleepEndTime == null) {
        timer.cancel();
        return;
      }
      final remaining = _sleepEndTime!.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _sleepTimerRemaining = null;
        _lastSleepRemainingMinutes = null;
        timer.cancel();
        return;
      }
      _sleepTimerRemaining = remaining;
      final minutes = remaining.inMinutes;
      if (_lastSleepRemainingMinutes != minutes) {
        _lastSleepRemainingMinutes = minutes;
        if (mounted) setState(() {});
      }
    });
    if (mounted) setState(() {});
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTickTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemaining = null;
    _sleepEndTime = null;
    _lastSleepRemainingMinutes = null;
    if (mounted) setState(() {});
  }

  // --- Share & Download ---
  void _shareSong(MediaItem mediaItem) {
    final ytid = mediaItem.extras?['ytid'] ?? mediaItem.id;
    final shareText =
        'Check out "${mediaItem.title}" by ${mediaItem.artist ?? 'Unknown Artist'}: https://youtube.com/watch?v=$ytid';
    Share.share(shareText, subject: mediaItem.title);
  }

  Future<void> _downloadSong(MediaItem mediaItem) async {
    final ytid = mediaItem.extras?['ytid'] ?? mediaItem.id;
    if (isSongAlreadyOffline(ytid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Song already downloaded'),
          backgroundColor: AuraColors.deepPurple,
        ),
      );
      return;
    }
    setState(() => _isDownloading = true);
    try {
      final imageUrl = _getValidImageUrlFromMediaItem(mediaItem);
      final songMap = {
        'ytid': ytid,
        'title': mediaItem.title,
        'artist': mediaItem.artist,
        'highResImage': imageUrl,
        'lowResImage': imageUrl,
        'duration': mediaItem.duration?.inMilliseconds ?? 0,
      };
      final success = await makeSongOffline(songMap);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(success ? 'Downloaded successfully' : 'Download failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // --- Queue Sheet ---
  void _showQueueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AuraColors.deepBlack,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Queue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<MediaItem>>(
                  stream: audioHandler.queue,
                  builder: (context, snapshot) {
                    final queue = snapshot.data ?? [];
                    final playlistSongs =
                        audioHandler.activePlaylist['list'] as List? ?? [];

                    final items = queue.isEmpty ? playlistSongs : queue;
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('Queue is empty',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                            SizedBox(height: 6),
                            Text('Search or play something to fill it up.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final isFromQueue = queue.isNotEmpty;
                        final dynamic item = isFromQueue
                            ? queue[index]
                            : (playlistSongs[index] as Map<String, dynamic>);
                        final currentMediaId = audioHandler.mediaItem.value?.id;
                        final isCurrentSong = isFromQueue
                            ? (item as MediaItem).id == currentMediaId
                            : index == audioHandler.activeSongId;

                        final title = isFromQueue
                            ? (item as MediaItem).title
                            : (item as Map<String, dynamic>)['title'] ??
                                'Unknown';
                        final artist = isFromQueue
                            ? (item as MediaItem).artist ?? 'Unknown Artist'
                            : (item as Map<String, dynamic>)['artist'] ??
                                'Unknown Artist';
                        final imageUrl = isFromQueue
                            ? _getValidImageUrlFromMediaItem(item as MediaItem)
                            : _getValidImageUrl(
                                item as Map<String, dynamic>,
                              );

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl == null || imageUrl.isEmpty
                                ? Container(
                                    width: 50,
                                    height: 50,
                                    color: AuraColors.surfaceLight,
                                    child: const Icon(Icons.music_note,
                                        color: Colors.white54),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 50,
                                      height: 50,
                                      color: AuraColors.surfaceLight,
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white54),
                                    ),
                                  ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: isCurrentSong
                                  ? AuraColors.electricViolet
                                  : Colors.white,
                              fontWeight: isCurrentSong
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            artist,
                            style: const TextStyle(color: Colors.white54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isCurrentSong
                              ? const Icon(Icons.equalizer_rounded,
                                  color: AuraColors.electricViolet)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            if (isFromQueue) {
                              audioHandler.skipToQueueItem(index);
                            } else {
                              audioHandler.skipToSong(index);
                            }
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
      ),
    );
  }

  // --- Helpers ---
  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  String? _getValidImageUrl(Map<String, dynamic> song) {
    final candidates = [
      song['highResImage'],
      song['image'],
      song['thumbnail'],
      song['lowResImage'],
    ];
    return candidates.firstWhere((url) => url != null && url != 'null',
        orElse: () => null);
  }

  String? _getValidImageUrlFromMediaItem(MediaItem item) {
    // Prioritize high-res image sources first
    final candidates = [
      item.extras?['highResImage'],
      item.extras?['artWorkPath'],
      item.artUri?.toString(),
      item.extras?['image'],
      item.extras?['thumbnail'],
      item.extras?['lowResImage'],
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      var value = candidate.toString();
      if (value.isNotEmpty && value != 'null') {
        // Upgrade YouTube thumbnail to maxresdefault if possible
        if (value.contains('i.ytimg.com') && !value.contains('maxresdefault')) {
          value = value
              .replaceAll('hqdefault.jpg', 'maxresdefault.jpg')
              .replaceAll('mqdefault.jpg', 'maxresdefault.jpg')
              .replaceAll('sddefault.jpg', 'maxresdefault.jpg')
              .replaceAll('default.jpg', 'maxresdefault.jpg');
        }
        return value;
      }
    }
    return null;
  }

  // --- Lyrics ---
  String? _lyricsPreview;

  Future<void> _fetchLyrics() async {
    final item = audioHandler.mediaItem.value;
    if (item == null) return;

    final songId = item.id;
    if (_currentLyricsSongId == songId && _lyricsFuture != null) return;
    _currentLyricsSongId = songId;

    setState(() {
      _lyricsFuture =
          getSongLyrics(item.artist ?? '', item.title).then((lyrics) {
        // Avoid stale response
        if (_currentLyricsSongId != songId) return LyricsReaderModel();
        if (lyrics == null) {
          _lyricsPreview = null;
          return LyricsReaderModel();
        }

        // Prepare a short preview: first 4 non-empty lines
        final lines = lyrics
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        final previewLines = lines.take(4).toList();
        _lyricsPreview = previewLines.join('\n');

        return LyricsHelper.prepareLyricsModel(
            lyrics, item.duration ?? Duration.zero);
      });
    });
  }

  // --- Business Logic (could be moved to service) ---
  bool isSongAlreadyOffline(String id) => _offlineSongs.contains(id);

  Future<bool> makeSongOffline(Map<String, dynamic> songData) async {
    final id = songData['ytid']?.toString() ?? '';
    if (id.isEmpty) return false;
    _offlineSongs.add(id);
    return true;
  }

  Future<String?> getSongLyrics(String artist, String title) async {
    try {
      final lyrics = await LyricsManager().fetchLyrics(artist, title);
      return lyrics;
    } catch (e) {
      return null;
    }
  }

  String addSongInCustomPlaylist(
      String playlistTitle, String audioId, Map<String, dynamic> songMap) {
    final existing = _customPlaylists.value.firstWhere(
      (p) => p['title'] == playlistTitle,
      orElse: () {
        final newPlaylist = {
          'title': playlistTitle,
          'list': <Map<String, dynamic>>[],
        };
        _customPlaylists.value = [..._customPlaylists.value, newPlaylist];
        return newPlaylist;
      },
    );
    final list = (existing['list'] as List).cast<Map<String, dynamic>>();
    if (list.any((s) => s['ytid'] == audioId)) {
      return 'Song already in playlist';
    }
    list.add(songMap);
    _customPlaylists.value = [..._customPlaylists.value];
    return 'Added to $playlistTitle';
  }

  void _showAddToPlaylistDialog(BuildContext context, MediaItem metadata) {
    final playlists = _customPlaylists.value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Playlist',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playlists.isEmpty)
              const Text(
                'No playlists yet. Tap the add button to create one.',
                style: TextStyle(color: Colors.black87),
              )
            else
              ...playlists.map(
                (playlist) => ListTile(
                  title: Text(
                    playlist['title'] ?? 'Untitled Playlist',
                    style: const TextStyle(color: Colors.black),
                  ),
                  subtitle: Text(
                    '${playlist['list']?.length ?? 0} songs',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  onTap: () async {
                    final audioId = metadata.extras?['ytid'] ?? metadata.id;
                    final imageUrl = _getValidImageUrlFromMediaItem(metadata);
                    final songMap = {
                      'ytid': audioId,
                      'title': metadata.title,
                      'artist': metadata.artist,
                      'image': imageUrl,
                      'duration': metadata.duration?.inMilliseconds ?? 0,
                    };
                    final result = addSongInCustomPlaylist(
                        playlist['title'], audioId, songMap);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result),
                        backgroundColor: AuraColors.deepPurple,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // --- UI Builders ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          if (mediaItem == null) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AuraColors.electricViolet));
          }
          final isVideoInitialized =
              ref.watch(playerProvider.select((s) => s.isVideoInitialized));
          final videoController =
              ref.watch(playerProvider.select((s) => s.videoController));
          final isLoadingRecommendations = ref.watch(
            playerProvider.select((s) => s.isLoadingRecommendations),
          );
          final recommendedSongs =
              ref.watch(playerProvider.select((s) => s.recommendedSongs));
          return _buildContent(
            mediaItem,
            isVideoInitialized: isVideoInitialized,
            videoController: videoController,
            isLoadingRecommendations: isLoadingRecommendations,
            recommendedSongs: recommendedSongs,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    MediaItem mediaItem, {
    required bool isVideoInitialized,
    required VideoPlayerController? videoController,
    required bool isLoadingRecommendations,
    required List<Map<String, dynamic>> recommendedSongs,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: _buildLivingBackground(
                isVideoInitialized: isVideoInitialized,
                videoController: videoController,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: _buildOverlay(isVideoInitialized),
          ),
        ),
        _buildContentUI(
          mediaItem,
          isVideoInitialized: isVideoInitialized,
          isLoadingRecommendations: isLoadingRecommendations,
          recommendedSongs: recommendedSongs,
        ),
      ],
    );
  }

  Widget _buildOverlay(bool isVideoInitialized) {
    // Only apply video overlay when player style is 'video'
    final showVideoStyle =
        isVideoInitialized && playerStyleSetting.value == 'video';
    if (showVideoStyle) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.3),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.5),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      );
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentUI(
    MediaItem mediaItem, {
    required bool isVideoInitialized,
    required bool isLoadingRecommendations,
    required List<Map<String, dynamic>> recommendedSongs,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Main scrollable content
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: (topPadding > 0 ? topPadding : 24) + 60, // Space for top bar
              left: 24,
              right: 24,
              bottom: 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: _buildArtworkOrLyrics(mediaItem, isVideoInitialized),
                ),
                if (!isVideoInitialized) const SizedBox(height: 40),
                _buildTrackInfo(mediaItem),
                const SizedBox(height: 24),
                _buildProgressBar(mediaItem),
                const SizedBox(height: 12),
                _buildControls(),
                const SizedBox(height: 48),
                // Show a small lyrics preview card when available and content is music
                _buildLyricsCard(mediaItem),

                // Show a small banner when video playback is temporarily disabled due to instability
                _buildVideoDisabledBanner(),
                _buildRecommendationCarousel(
                  mediaItem: mediaItem,
                  isLoadingRecommendations: isLoadingRecommendations,
                  recommendedSongs: recommendedSongs,
                ),
                _buildBottomOptions(mediaItem),
              ],
            ),
          ),
        ),
        // Top bar as overlay
        Positioned(
          top: (topPadding > 0 ? topPadding : 24) + 8,
          left: 0,
          right: 0,
          child: _buildTopBar(),
        ),
      ],
    );
  }

  // --- Fullscreen Video Overlay Logic ---
  void _openFullscreenVideo() async {
    final ok = await ref.read(playerProvider.notifier).prepareFullscreen();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full video not available')));
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) {
          return const _FullscreenVideoOverlay();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        GestureDetector(
          onTap: _showQueueSheet,
          child: Row(
            children: [
              const Text(
                'Now Playing',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
              ),
              if (_sleepTimer != null)
                Icon(Icons.timer_rounded,
                    color: AuraColors.electricViolet, size: 16),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(FluentIcons.list_24_regular, color: Colors.white),
          onPressed: _showQueueSheet,
        ),
      ],
    );
  }

  Widget _buildArtworkOrLyrics(MediaItem mediaItem, bool isVideoInitialized) {
    if (_showLyrics && _currentLyricsSongId != mediaItem.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchLyrics();
      });
    }
    final size = MediaQuery.of(context).size.width * 0.85;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showLyrics
          ? SizedBox(
              key: const ValueKey('lyrics_view'),
              height: size,
              width: size,
              child: _buildLyricsView(mediaItem))
          : KeyedSubtree(
              key: const ValueKey('artwork_view'),
              child: _buildArtwork(mediaItem, isVideoInitialized),
            ),
    );
  }

  Widget _buildArtwork(MediaItem mediaItem, bool isVideoInitialized) {
    final size = MediaQuery.of(context).size.width * 0.85;

    // Maintain layout structure only when video style is active AND video is playing
    final showVideoStyle =
        isVideoInitialized && playerStyleSetting.value == 'video';

    // If video is active, show it inside this card instead of empty SizedBox
    if (showVideoStyle) {
      final controller = ref.read(playerProvider).videoController;

      // If we are in Background Mode, this card should be a transparent placeholder
      // (The video is running in _buildLivingBackground)
      if (_isBackgroundVideoMode) {
        return SizedBox(height: size, width: size);
      }

      if (controller != null && controller.value.isInitialized) {
        return Hero(
          tag: 'video_player_card', // Tag for Hero transition from fullscreen
          child: Container(
            width: size,
            height:
                size, // Keep it square or adjust to aspect ratio within this box
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller, key: _videoPlayerKey),
                ),
              ),
            ),
          ),
        );
      }
    }

    final imageUrl = _getValidImageUrlFromMediaItem(mediaItem);

    final artworkTag =
        'artwork_${(mediaItem.id ?? mediaItem.title ?? mediaItem.hashCode).toString()}';
    return Hero(
      tag: artworkTag,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: imageUrl == null
              ? Container(color: AuraColors.surfaceLight)
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  // Request a higher cache size proportional to device pixel ratio
                  memCacheHeight:
                      (size * MediaQuery.of(context).devicePixelRatio * 2)
                          .toInt(),
                  memCacheWidth:
                      (size * MediaQuery.of(context).devicePixelRatio * 2)
                          .toInt(),
                  // Render using an Image widget with high filter quality for crisp scaling
                  imageBuilder: (context, imageProvider) => Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    filterQuality: FilterQuality.high,
                  ),
                  placeholder: (_, __) => Container(
                    color: AuraColors.surfaceLight,
                  ),
                  errorWidget: (_, __, ___) =>
                      Container(color: AuraColors.surfaceLight),
                ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(MediaItem mediaItem) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mediaItem.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                mediaItem.artist ?? 'Unknown Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white60,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivingBackground({
    required bool isVideoInitialized,
    required VideoPlayerController? videoController,
  }) {
    final showVideo = isVideoInitialized && playerStyleSetting.value == 'video';

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. The Mesh Gradient (Always present as base)
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _meshController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      Color(0xFF4C1D95),
                      Color(0xFF8B5CF6),
                      Colors.black,
                    ],
                    stops: const [0, 0.5, 1],
                    transform:
                        GradientRotation(_meshController.value * 2 * 3.14159),
                  ),
                ),
              );
            },
          ),
        ),

        // 2. The Video Background (Only if in Background Mode)
        if (showVideo && _isBackgroundVideoMode && videoController != null)
          Positioned.fill(
            child: Hero(
              tag: 'video_player_card',
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: videoController.value.size.width,
                  height: videoController.value.size.height,
                  child: VideoPlayer(videoController, key: _videoPlayerKey),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(MediaItem mediaItem) {
    final positionStream = AudioService.position.map((d) {
      final ms = d.inMilliseconds;
      final bucketed = ms - (ms % 500); // less frequent updates
      return Duration(milliseconds: bucketed);
    }).distinct();

    final duration = mediaItem.duration ?? Duration.zero;

    return StreamBuilder<Duration>(
      stream: positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
                trackShape: const RoundedRectSliderTrackShape(),
                activeTrackColor: AuraColors.electricViolet,
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                overlayColor: AuraColors.electricViolet.withValues(alpha: 0.1),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: position.inSeconds
                    .toDouble()
                    .clamp(0, duration.inSeconds.toDouble()),
                max: duration.inSeconds.toDouble().clamp(1, double.infinity),
                onChanged: (val) {
                  final seekPos = Duration(seconds: val.toInt());
                  audioHandler.seek(seekPos);
                },
                onChangeEnd: (val) {
                  final seekPos = Duration(seconds: val.toInt());
                  ref.read(playerProvider.notifier).seekVideo(seekPos);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color:
                _isShuffleEnabled ? AuraColors.electricViolet : Colors.white38,
            size: 24,
          ),
          onPressed: _toggleShuffle,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded,
                  color: Colors.white, size: 48),
              onPressed: audioHandler.skipToPrevious,
            ),
            const SizedBox(width: 16),
            _buildPlayPauseButton(),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded,
                  color: Colors.white, size: 48),
              onPressed: audioHandler.skipToNext,
            ),
          ],
        ),
        IconButton(
          icon: Icon(_getRepeatIcon(),
              color: _repeatMode != LoopMode.off
                  ? AuraColors.electricViolet
                  : Colors.white38,
              size: 24),
          onPressed: _cycleRepeatMode,
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton() {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        final processingState =
            snapshot.data?.processingState ?? AudioProcessingState.idle;
        final isLoading = processingState == AudioProcessingState.loading ||
            processingState == AudioProcessingState.buffering;
        return GestureDetector(
          onTap: () => playing ? audioHandler.pause() : audioHandler.play(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: playing ? 78 : 72,
            height: playing ? 78 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AuraColors.electricViolet.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 3),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 38,
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationCarousel({
    required MediaItem mediaItem,
    required bool isLoadingRecommendations,
    required List<Map<String, dynamic>> recommendedSongs,
  }) {
    // Helper to classify likely music based on metadata
    bool _isLikelyMusic(MediaItem item) {
      final title = (item.title ?? '').toString().toLowerCase();
      final artist = (item.artist ?? '').toString().toLowerCase();
      final lowerExtras =
          (item.extras ?? {}).map((k, v) => MapEntry(k.toString(), v));

      // If explicitly marked podcast/speech in extras
      if (item.extras != null) {
        final isPodcast =
            item.extras?['isPodcast'] ?? item.extras?['is_podcast'];
        if (isPodcast == true) return false;
      }

      const nonMusicKeywords = [
        'podcast',
        'interview',
        'episode',
        'pod cast',
        'panel',
        'discussion',
        'talk',
        'lecture',
        'press',
        'news',
        'conference',
        'webinar'
      ];

      for (final k in nonMusicKeywords) {
        if (title.contains(k) || artist.contains(k)) return false;
      }

      // Heuristic: extremely long durations likely speech/podcast (e.g., > 20 mins)
      final dur = item.duration ?? Duration.zero;
      if (dur.inMinutes > 20) return false;

      return true;
    }

    if (isLoadingRecommendations) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(
              color: AuraColors.electricViolet, strokeWidth: 2),
        ),
      );
    }

    // Defensive: remove any recommendations that match the current playing song
    final currentYt = mediaItem.extras?['ytid'] ?? mediaItem.id;
    final filtered = recommendedSongs.where((s) {
      final sid = (s['ytid'] ?? s['id'])?.toString();
      return sid != null && sid != currentYt?.toString();
    }).toList();

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12, left: 16, right: 16),
          child: Text(
            'You might like',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) =>
                _buildRecommendationTile(filtered[index], filtered, index),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildRecommendationTile(Map<String, dynamic> song,
      List<Map<String, dynamic>> playlist, int index) {
    final title = song['title'] ?? 'Unknown Title';
    final artist = song['artist'] ?? 'Unknown Artist';
    final imageUrl = _getValidImageUrl(song) ?? '';

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Play the selected song as part of the recommended playlist so next/previous work
            await audioHandler.playPlaylistSong(
                playlist: {'list': playlist}, songIndex: index);
          },
          onLongPress: () async {
            // Long-press to preview lyrics (if available) — fetch lyrics for the tapped recommendation
            try {
              final audioId = song['ytid'] ?? song['id'];
              final previewLyrics = await getSongLyrics(
                  song['artist']?.toString() ?? '',
                  song['title']?.toString() ?? '');
              if (previewLyrics != null && previewLyrics.isNotEmpty) {
                // Show a simple dialog with a preview
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(title),
                      content: SingleChildScrollView(
                        child: Text(previewLyrics
                            .split(RegExp('\r?\n'))
                            .take(6)
                            .join('\n')),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                }
              }
            } catch (e, st) {
              logger.log('PlayerPage: lyrics preview failed', e, st);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: () {
                          if (imageUrl.isNotEmpty) {
                            final uri = Uri.tryParse(imageUrl);
                            if (uri != null &&
                                (uri.isScheme('http') ||
                                    uri.isScheme('https'))) {
                              return CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => ColoredBox(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                errorWidget: (_, __, ___) => ColoredBox(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white24, size: 20),
                                ),
                              );
                            }

                            // Treat as a local file if possible
                            try {
                              final file = File(imageUrl);
                              if (file.existsSync()) {
                                return Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                );
                              }
                            } catch (_) {
                              // ignore and fall through to placeholder
                            }
                          }

                          return ColoredBox(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(Icons.music_note,
                                color: Colors.white24, size: 20),
                          );
                        }(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOptions(MediaItem mediaItem) {
    final ytid = mediaItem.extras?['ytid'] ?? mediaItem.id;
    final isOffline = isSongAlreadyOffline(ytid);

    // Check YAMNet classification for this media item (if available)
    final yamnetMap =
        ref.watch(playerProvider.select((s) => s.yamnetClassification));
    final yamnetConf =
        ref.watch(playerProvider.select((s) => s.yamnetConfidence));
    final classification = yamnetMap[ytid];
    final classificationConfidence = yamnetConf[ytid] ?? 0.0;
    final disableLyricsDueToYamnet = classification != null &&
        classification.toLowerCase() == 'speech' &&
        classificationConfidence > 0.02;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.lyrics_outlined,
            color: _showLyrics ? AuraColors.electricViolet : Colors.white70,
          ),
          onPressed: disableLyricsDueToYamnet
              ? null
              : () {
                  setState(() => _showLyrics = !_showLyrics);
                  if (_showLyrics &&
                      (_lyricsFuture == null ||
                          _currentLyricsSongId != mediaItem.id)) {
                    _fetchLyrics();
                  }
                },
        ),
        // Timer Button
        IconButton(
          icon: Icon(
            Icons.timer_outlined,
            color: _sleepTimer != null
                ? AuraColors.electricViolet
                : Colors.white70,
          ),
          onPressed: _showSleepTimerDialog,
        ),

        _buildLikeButton(mediaItem),

        // Dock/Fullscreen Toggle Button (only when video style is active)
        if (playerStyleSetting.value == 'video')
          IconButton(
            // When expanded (background mode), show 'exit/shrink' icon. Otherwise 'expand' icon.
            icon: Icon(
                _isBackgroundVideoMode
                    ? Icons.fullscreen_exit_rounded
                    : Icons.aspect_ratio_rounded,
                color: _isBackgroundVideoMode
                    ? AuraColors.electricViolet
                    : Colors.white70),
            onPressed: () {
              setState(() {
                _isBackgroundVideoMode = !_isBackgroundVideoMode;
              });
            },
          )
        else
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white70),
            onPressed: () => _shareSong(mediaItem),
          ),

        _isDownloading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: AuraColors.electricViolet, strokeWidth: 2),
              )
            : IconButton(
                icon: Icon(
                  isOffline
                      ? Icons.download_done_rounded
                      : Icons.download_rounded,
                  color: isOffline ? AuraColors.electricViolet : Colors.white70,
                ),
                onPressed: isOffline ? null : () => _downloadSong(mediaItem),
              ),
      ],
    );
  }

  Widget _buildLikeButton(MediaItem mediaItem) {
    final audioId = mediaItem.extras?['ytid'] ?? mediaItem.id;
    final isLiked = musify.isSongAlreadyLiked(audioId);
    return IconButton(
      icon: Icon(
        isLiked ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
        color: isLiked ? AuraColors.electricViolet : Colors.white70,
      ),
      onPressed: () async {
        await musify.updateSongLikeStatus(audioId, !isLiked);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildLyricsView(MediaItem mediaItem) {
    if (_lyricsFuture == null) {
      return const Center(
        child: CircularProgressIndicator(color: AuraColors.electricViolet),
      );
    }
    return FutureBuilder<LyricsReaderModel>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator(color: AuraColors.electricViolet));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No lyrics found',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap the lyric icon later to refresh the search.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return StreamBuilder<Duration>(
          stream: AudioService.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data?.inMilliseconds ?? 0;
            final playing = audioHandler.playbackState.value.playing;
            return LyricsReader(
              model: snapshot.data,
              position: position,
              lyricUi: UINetease()
                ..defaultSize = 18
                ..defaultExtSize = 14
                ..otherMainSize = 16
                ..bias = 0.5
                ..lineGap = 25
                ..inlineGap = 25
                ..lyricAlign = LyricAlign.CENTER
                ..highlight = true,
              playing: playing,
              size: const Size(_artworkSize, _artworkSize),
              emptyBuilder: () => const Center(
                child: Text('Loading lyrics...',
                    style: TextStyle(color: Colors.white)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLyricsCard(MediaItem mediaItem) {
    // Skip lyrics card when video is expanded in background mode — video takes priority
    if (_isBackgroundVideoMode) {
      return const SizedBox.shrink();
    }

    // Skip showing lyrics preview for long-form content or explicitly-marked podcasts
    final isPodcast =
        mediaItem.extras?['isPodcast'] ?? mediaItem.extras?['is_podcast'];
    final duration = mediaItem.duration ?? Duration.zero;
    if (isPodcast == true || duration.inMinutes > 20) {
      return const SizedBox.shrink();
    }

    // If YAMNet classification exists and indicates non-music (speech) with reasonable confidence, avoid showing lyrics
    final id = mediaItem.extras?['ytid'] ?? mediaItem.id;
    final yamnetMap =
        ref.watch(playerProvider.select((s) => s.yamnetClassification));
    final yamnetConf =
        ref.watch(playerProvider.select((s) => s.yamnetConfidence));
    final classification = yamnetMap[id];
    final confidence = yamnetConf[id] ?? 0.0;
    if (classification != null &&
        classification.toLowerCase() == 'speech' &&
        confidence > 0.02) {
      return const SizedBox.shrink();
    }

    // Trigger a fetch if we haven't tried yet
    if (_lyricsPreview == null && _lyricsFuture == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchLyrics();
      });
    }

    if (_lyricsPreview == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _showLyrics = true);
            if (_lyricsFuture == null) _fetchLyrics();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lyrics preview',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  _lyricsPreview ?? '',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Text('Tap to open full lyrics',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoDisabledBanner() {
    final disabled =
        ref.watch(playerProvider.select((s) => s.videoDisabledFallback));
    final until = ref.watch(playerProvider.select((s) => s.videoDisabledUntil));

    if (!disabled || until == null) return const SizedBox.shrink();

    final remaining = until.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Video disabled due to instability — retrying in ${remaining}s',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
            TextButton(
              onPressed: () {
                // Provide a manual retry by clearing the fallback state and trying to init video again
                ref.read(playerProvider.notifier).manualRetryVideoInit();
              },
              child:
                  const Text('Retry', style: TextStyle(color: Colors.orange)),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge); // Restore default
    // Cancel timers directly to avoid setState in dispose
    _sleepTimer?.cancel();
    _sleepTickTimer?.cancel();
    _meshController.dispose();
    super.dispose();
  }
}

class _FullscreenVideoOverlay extends ConsumerStatefulWidget {
  const _FullscreenVideoOverlay();

  @override
  ConsumerState<_FullscreenVideoOverlay> createState() =>
      _FullscreenVideoOverlayState();
}

class _FullscreenVideoOverlayState
    extends ConsumerState<_FullscreenVideoOverlay>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isDocked = false; // toggles animation state

  static const _toggleDuration = Duration(milliseconds: 650);
  static const _toggleCurve = Curves.easeInOutBack;

  @override
  void initState() {
    super.initState();
    // Enable immersive mode immediately
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Grab the active controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(playerProvider).videoController;
      setState(() => _controller = controller);
    });
  }

  @override
  void dispose() {
    // Restore system UI when this overlay pops
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.read(playerProvider.notifier).exitFullscreen();
    super.dispose();
  }

  Future<void> _handleUndock() async {
    setState(() => _isDocked = true);
    // Wait for the "shrink to card" animation
    await Future.delayed(_toggleDuration);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors
          .transparent, // Transparent so Hero works visually if needed, but we use black in container
      body: Stack(
        children: [
          // The Black Background - fades out when docked?
          // If we want the seamless effect, the background should probably be strictly behind the video
          // For now, let's keep it black to cover the PlayerPage content
          if (!_isDocked)
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

          Align(
            alignment: Alignment.topCenter,
            child: Hero(
              tag: 'video_player_card', // Matches PlayerPage tag
              child: AnimatedPadding(
                duration: _toggleDuration,
                curve: _toggleCurve,
                // When docked, padding pushes it down to match Card position
                padding: _isDocked
                    ? EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 90,
                        left: (MediaQuery.of(context).size.width * 0.075),
                        right: (MediaQuery.of(context).size.width * 0.075),
                      )
                    : EdgeInsets.zero,
                child: AnimatedContainer(
                  duration: _toggleDuration,
                  curve: _toggleCurve,
                  width: _isDocked
                      ? MediaQuery.of(context).size.width * 0.85
                      : MediaQuery.of(context).size.width,
                  height: _isDocked
                      ? MediaQuery.of(context).size.width *
                          0.85 // Square to match artwork size
                      : MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(_isDocked ? 28.0 : 0.0),
                    boxShadow: _isDocked
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_isDocked ? 28.0 : 0.0),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Controls Layer - fade out when docked
          if (!_isDocked)
            GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              behavior: HitTestBehavior.translucent,
              child: _showControls
                  ? _buildControlsOverlay()
                  : Container(color: Colors.transparent),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // Top-right undock toggle
        Positioned(
          top: 16,
          right: 32, // Adjusted padding for immersive
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.fullscreen_exit,
                  color: Colors.white, size: 30),
              onPressed: _handleUndock,
            ),
          ),
        ),

        // Bottom controls
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                        _controller!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 64),
                    onPressed: () {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
