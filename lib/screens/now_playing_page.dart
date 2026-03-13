import 'dart:async';

import 'dart:typed_data';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/main.dart';
import 'package:dew/models/position_data.dart';
import 'package:dew/screens/music_share.dart'; // added import
import 'package:dew/services/data_manager.dart';
import 'package:dew/services/yamnet_classifier.dart';
import 'package:dew/utilities/formatter.dart';
import 'package:dew/widgets/marque.dart';
import 'package:dew/widgets/song_artwork.dart';
import 'package:dew/widgets/spinner.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ignore: depend_on_referenced_packages
import 'package:headset_connection_event/headset_event.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:dew/widgets/spotify_lyrics_view.dart';

/// Plays a suggested song by invoking the audio handler.
Future<void> playSuggestedSong(Map<String, dynamic> suggestion) async {
  try {
    print('🎵 playSuggestedSong() raw suggestion: $suggestion');

    // Sanitize each field to ensure proper types
    final ytid = (suggestion['ytid'] ?? suggestion['id'] ?? '').toString();
    final title = (suggestion['title'] ?? 'Unknown Title').toString();
    final artist = (suggestion['artist'] ?? 'Unknown Artist').toString();
    final image = (suggestion['image'] ?? '').toString();

    // Handle duration properly
    final durationRaw = suggestion['duration'];
    Duration duration;
    if (durationRaw is int) {
      duration = Duration(milliseconds: durationRaw);
    } else if (durationRaw is Duration) {
      duration = durationRaw;
    } else {
      duration = Duration.zero;
    }

    final songDetails = {
      'ytid': ytid,
      'title': title,
      'artist': artist,
      'image': image,
      'duration': duration,
      'isLive': suggestion['isLive'] ?? false,
      'isVideo': suggestion['isVideo'] ?? false,
    };

    print('🎵 playSuggestedSong() sanitized: $songDetails');
    await audioHandler.playSong(songDetails);
  } catch (e, stackTrace) {
    print('❌ playSuggestedSong failed: $e');
    print('Stack trace: $stackTrace');
  }
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});
  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _volumeAnimationController;
  late Animation<double> _volumeAnimation;

  // Simplified Enhanced Listening - Volume Control Only
  ValueNotifier<bool> _enableSmartVolume = ValueNotifier<bool>(false);
  ValueNotifier<String> _currentEnvironment = ValueNotifier<String>('Unknown');
  ValueNotifier<double> _currentVolume = ValueNotifier<double>(0.8);
  ValueNotifier<double> _confidenceLevel = ValueNotifier<double>(0.0);
  ValueNotifier<bool> _isAnalyzing = ValueNotifier<bool>(false);

  Stream<Uint8List>? _micStream;
  StreamSubscription<Uint8List>? _micSubscription;
  Timer? _analysisTimer;
  YAMNetTFLiteClassifier? _yamnetClassifier;
  List<Uint8List> _audioBuffer = [];
  double _baseVolume = 0.8; // User's preferred volume
  double _targetVolume = 0.8; // AI-adjusted target volume

  // Background video (player style)
  VideoPlayerController? _bgVideoController;
  Future<void>? _bgInitFuture;
  String? _bgVideoId;
  bool _bgVideoLoading = false;

  // Add this as a class variable
  int _analysisCount = 0;
  List<double> _analysisTimes = [];

  // Add these resume-related variables
  ValueNotifier<bool> _showResumeDialog = ValueNotifier<bool>(false);
  Map<String, dynamic>? _lastPlaybackState;
  Timer? _stateBackupTimer;

  // Add these to track playback state
  DateTime? _lastActiveTime;
  static const Duration _resumeThreshold = Duration(
      minutes:
          5); // Show resume dialog if app was closed for less than 5 minutes

  // Add these Bluetooth/headphone detection variables
  final _headsetPlugin = HeadsetEvent();
  ValueNotifier<bool> _hasHeadphones = ValueNotifier<bool>(false);
  ValueNotifier<bool> _hasBluetoothHeadphones = ValueNotifier<bool>(false);
  ValueNotifier<bool> _isCheckingHeadphones = ValueNotifier<bool>(false);
  Timer? _bluetoothCheckTimer;
  StreamSubscription? _audioSessionSubscription;

  @override
  void initState() {
    super.initState();
    print(
        'NOW_PLAYING_INIT: initState called, playerStyle=${playerStyleSetting.value}');

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    _volumeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _volumeAnimation = Tween<double>(
      begin: 0.8,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _volumeAnimationController,
      curve: Curves.easeInOut,
    ));

    _volumeAnimation.addListener(() {
      _currentVolume.value = _volumeAnimation.value;
      audioHandler
          .customAction('setVolume', {'volume': _volumeAnimation.value});
    });

    // Initialize headphone detection
    _initializeHeadphoneDetection();

    // Start state backup
    _startStateBackup();

    // Check for resume dialog after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForResumeDialog();
    });
  }

  // Start state backup
  void _startStateBackup() {
    _stateBackupTimer?.cancel();
    _stateBackupTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _savePlaybackState();
    });
  }

// Stop state backup
  void _stopStateBackup() {
    _stateBackupTimer?.cancel();
    _stateBackupTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App is going to background or being closed
        _savePlaybackState();
        print('📱 App paused - saving playback state');
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        print('📱 App resumed');
        break;
      default:
        break;
    }
  }

  // Check if we should show resume dialog
  Future<void> _checkForResumeDialog() async {
    if (await _shouldShowResumeDialog()) {
      _lastPlaybackState = await _loadPlaybackState();
      if (_lastPlaybackState != null) {
        // Wait a bit for the UI to settle
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          _showResumePlaybackDialog();
        }
      }
    }
  }

  void _showResumePlaybackDialog() {
    if (_lastPlaybackState == null || !mounted) return;

    final theme = Theme.of(context);
    final title = _lastPlaybackState!['title'] as String? ?? 'Unknown';
    final artist = _lastPlaybackState!['artist'] as String? ?? 'Unknown Artist';
    final position =
        Duration(milliseconds: _lastPlaybackState!['position'] as int? ?? 0);
    final duration =
        Duration(milliseconds: _lastPlaybackState!['duration'] as int? ?? 0);
    final artUri = _lastPlaybackState!['artUri'] as String?;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  FluentIcons.play_circle_24_filled,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Resume Playback?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Song info card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: artUri != null
                        ? Image.network(
                            artUri,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                color: theme.colorScheme.surfaceVariant,
                                child: Icon(
                                  FluentIcons.music_note_2_24_filled,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: theme.colorScheme.surfaceVariant,
                            child: Icon(
                              FluentIcons.music_note_2_24_filled,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                  ),

                  SizedBox(width: 16),

                  // Song details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          artist,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        // Progress indicator
                        Row(
                          children: [
                            Icon(
                              FluentIcons.clock_24_regular,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Left off at ${formatDuration(position.inSeconds)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Progress bar
            Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: theme.colorScheme.surfaceVariant,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: duration.inMilliseconds > 0
                        ? (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDuration(position.inSeconds),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatDuration(duration.inSeconds),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear the saved state so it doesn't show again
              addOrUpdateData('user', 'lastPlaybackState', null);
            },
            child: Text(
              'Start Fresh',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _resumePlayback();
            },
            icon: Icon(FluentIcons.play_24_filled, size: 18),
            label: Text('Resume'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoHeadphonesDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('No Headphones Detected'),
        content: Text(
            'Please connect Bluetooth headphones to enable Adaptive Audio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Check if we should show resume dialog
  Future<bool> _shouldShowResumeDialog() async {
    final savedState = await _loadPlaybackState();
    if (savedState == null) return false;

    final timestamp = savedState['timestamp'] as int?;
    if (timestamp == null) return false;

    final lastTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final timeDiff = DateTime.now().difference(lastTime);

    // Show resume dialog if app was closed for less than 30 minutes
    // and the song had meaningful progress (more than 30 seconds)
    final position = savedState['position'] as int? ?? 0;
    final duration = savedState['duration'] as int? ?? 0;

    return timeDiff < Duration(minutes: 30) &&
        position > 30000 && // More than 30 seconds
        position < duration - 30000; // Not near the end
  }

  // Resume playback from saved state
  Future<void> _resumePlayback() async {
    if (_lastPlaybackState == null) return;

    try {
      print('🔄 Resuming playback...');

      // Create MediaItem from saved state
      final songDetails = {
        'ytid': _lastPlaybackState!['songId'],
        'title': _lastPlaybackState!['title'],
        'artist': _lastPlaybackState!['artist'],
        'image': _lastPlaybackState!['artUri'],
        'duration':
            Duration(milliseconds: _lastPlaybackState!['duration'] as int),
      };

      // Add any extra data that was saved
      if (_lastPlaybackState!['extras'] != null) {
        songDetails
            .addAll(_lastPlaybackState!['extras'] as Map<String, dynamic>);
      }

      // Start playing the song
      await audioHandler.playSong(songDetails);

      // Wait a bit for the song to load
      await Future.delayed(Duration(milliseconds: 1000));

      // Seek to the saved position
      final savedPosition =
          Duration(milliseconds: _lastPlaybackState!['position'] as int);
      await audioHandler.seek(savedPosition);

      // Resume playback if it was playing
      final wasPlaying = _lastPlaybackState!['isPlaying'] as bool? ?? false;
      if (wasPlaying) {
        await audioHandler.play();
      }

      print(
          '✅ Resumed: ${_lastPlaybackState!['title']} at ${formatDuration(savedPosition.inSeconds)}');

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(FluentIcons.checkmark_circle_24_filled,
                    color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Resumed from ${formatDuration(savedPosition.inSeconds)}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Clear the saved state
      addOrUpdateData('user', 'lastPlaybackState', null);
    } catch (e) {
      print('Error resuming playback: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resume playback'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: playerStyleSetting,
      builder: (context, style, _) {
        final isVideoStyle = style == 'video';
        print(
            'NOW_PLAYING_BUILD: playerStyle=$style, isVideoStyle=$isVideoStyle');

        return Scaffold(
          backgroundColor:
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.98),
          extendBodyBehindAppBar: isVideoStyle,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: BackButton(color: theme.colorScheme.onSurface),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (isVideoStyle) _buildVideoBackground(theme),
              StreamBuilder<MediaItem?>(
                stream: audioHandler.mediaItem,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(child: Spinner());
                  }
                  final metadata = snapshot.data!;
                  _ensureBackgroundVideo(metadata, isVideoStyle);
                  return SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.0,
                        vertical: isVideoStyle ? 12.0 : 0.0,
                      ).add(
                        EdgeInsets.only(
                          top: isVideoStyle
                              ? MediaQuery.of(context).padding.top +
                                  kToolbarHeight
                              : 0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 18),
                          Material(
                            elevation: 10,
                            borderRadius: BorderRadius.circular(24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: GestureDetector(
                                onDoubleTap: () async {
                                  final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Share this song?'),
                                          content: const Text(
                                              'Send this song to a nearby device using NFC or manual code.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel')),
                                            ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Yes')),
                                          ],
                                        ),
                                      ) ??
                                      false;

                                  if (confirmed && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => MusicSharePage(
                                              metadata: metadata)),
                                    );
                                  }
                                },
                                child: SongArtworkWidget(
                                  metadata: metadata,
                                  size: size.width * 0.7,
                                  errorWidgetIconSize: size.width / 8,
                                  borderRadius: 24,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          MarqueeWidget(
                            child: Text(
                              metadata.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (metadata.artist != null)
                            Text(
                              metadata.artist!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 24),
                          StreamBuilder<PositionData>(
                            stream: audioHandler.positionDataStream,
                            builder: (context, snapshot) {
                              final positionData = snapshot.data ??
                                  PositionData(Duration.zero, Duration.zero,
                                      Duration.zero);
                              return Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 5,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 8),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                              overlayRadius: 16),
                                      activeTrackColor:
                                          theme.colorScheme.primary,
                                      inactiveTrackColor: theme
                                          .colorScheme.onSurface
                                          .withOpacity(0.2),
                                      thumbColor: theme.colorScheme.primary,
                                    ),
                                    child: Slider(
                                      value: positionData.position.inSeconds
                                          .toDouble()
                                          .clamp(
                                              0.0,
                                              positionData.duration.inSeconds
                                                  .toDouble()),
                                      max: positionData.duration.inSeconds
                                                  .toDouble() >
                                              0
                                          ? positionData.duration.inSeconds
                                              .toDouble()
                                          : 1.0,
                                      onChanged: (value) {
                                        audioHandler.seek(
                                            Duration(seconds: value.toInt()));
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formatDuration(
                                              positionData.position.inSeconds),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          formatDuration(
                                              positionData.duration.inSeconds),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildPlayerControls(context, metadata),
                          const SizedBox(height: 18),
                          _buildBottomActions(context, metadata),
                          const SizedBox(height: 18),
                          _buildSmartVolumeSection(theme),
                          const SizedBox(height: 18),
                          _buildLyricsSection(metadata, theme),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerControls(BuildContext context, MediaItem metadata) {
    final theme = Theme.of(context);
    final _primaryColor = theme.colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Backward / Replay 10 seconds button
        GestureDetector(
          onLongPress: () => audioHandler.skipToPrevious(),
          child: IconButton(
            icon: Icon(Icons.replay_10, color: _primaryColor),
            iconSize: 34,
            onPressed: () {
              final currentPosition = audioHandler.playbackState.value.position;
              audioHandler.seek(currentPosition - const Duration(seconds: 10));
            },
          ),
        ),
        // Play/Pause button
        StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data?.playing ?? false;
            return IconButton(
              icon: Icon(
                isPlaying
                    ? FluentIcons.pause_24_filled
                    : FluentIcons.play_24_filled,
                color: _primaryColor,
              ),
              iconSize: 48,
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
        // Forward 10 seconds button
        GestureDetector(
          onLongPress: () => audioHandler.skipToNext(),
          child: IconButton(
            icon: Icon(Icons.forward_10, color: _primaryColor),
            iconSize: 34,
            onPressed: () {
              final currentPosition = audioHandler.playbackState.value.position;
              audioHandler.seek(currentPosition + const Duration(seconds: 10));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, MediaItem metadata) {
    final theme = Theme.of(context);
    final _primaryColor = theme.colorScheme.primary;
    final audioId = metadata.extras?['ytid'] ?? metadata.id;
    final songLikeStatus = ValueNotifier<bool>(isSongAlreadyLiked(audioId));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Like Song Icon
        ValueListenableBuilder<bool>(
          valueListenable: songLikeStatus,
          builder: (_, isLiked, __) {
            return IconButton(
              icon: Icon(
                isLiked
                    ? FluentIcons.heart_24_filled
                    : FluentIcons.heart_24_regular,
                color: _primaryColor,
              ),
              iconSize: 28,
              onPressed: () async {
                if (isLiked) {
                  // Remove song from "Liked Songs"
                  await updateSongLikeStatus(audioId, false);
                } else {
                  // Add song to "Liked Songs"
                  await updateSongLikeStatus(audioId, true);
                }
                songLikeStatus.value = !isLiked;
              },
            );
          },
        ),
        // Add to Playlist Icon
        IconButton(
          icon: Icon(FluentIcons.add_24_filled, color: _primaryColor),
          iconSize: 28,
          onPressed: () {
            _showAddToPlaylistDialog(context, metadata);
          },
        ),
        // Volume Icon with Current Level
        ValueListenableBuilder<double>(
          valueListenable: _currentVolume,
          builder: (context, volume, _) {
            return IconButton(
              icon: Icon(
                volume > 0.7
                    ? FluentIcons.speaker_2_24_filled
                    : volume > 0.3
                        ? FluentIcons.speaker_1_24_filled
                        : FluentIcons.speaker_0_24_filled,
                color: _primaryColor,
              ),
              iconSize: 28,
              onPressed: () {
                _showVolumeDialog(context);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoBackground(ThemeData theme) {
    final controller = _bgVideoController;
    final isInitialized = controller?.value.isInitialized ?? false;

    print(
        'VIDEO_BG_BUILD: isInitialized=$isInitialized, loading=$_bgVideoLoading');

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else if (_bgVideoLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surfaceVariant.withOpacity(0.85),
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          // Dark overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.45),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureBackgroundVideo(
      MediaItem metadata, bool isVideoStyle) async {
    final videoId = metadata.extras?['ytid']?.toString() ?? metadata.id;

    print('ENSURE_VIDEO: videoId=$videoId, isVideoStyle=$isVideoStyle');

    if (!isVideoStyle) {
      if (_bgVideoController != null || _bgVideoId != null) {
        print('ENSURE_VIDEO: Video style disabled, cleaning up');
        _bgVideoId = null;
        _bgInitFuture = null;
        _bgVideoController?.dispose();
        _bgVideoController = null;
        if (mounted) setState(() {});
      }
      return;
    }

    if (videoId.isEmpty) {
      print('ENSURE_VIDEO: videoId is empty, skipping');
      return;
    }

    final alreadyLoaded = _bgVideoId == videoId &&
        (_bgVideoController?.value.isInitialized ?? false);
    if (alreadyLoaded) {
      print('ENSURE_VIDEO: Video already loaded for $videoId');
      return;
    }

    if (_bgVideoLoading && _bgVideoId == videoId) {
      print('ENSURE_VIDEO: Already loading video for $videoId');
      return;
    }

    print('ENSURE_VIDEO: Starting video load for $videoId');
    _bgVideoId = videoId;
    _bgVideoController?.dispose();
    _bgVideoController = null;
    _bgVideoLoading = true;

    _bgInitFuture = () async {
      try {
        print('ENSURE_VIDEO: Fetching video stream URL for $videoId');
        final streamInfo =
            await getVideoStreamUrl(videoId, targetQuality: 1080);
        final url = streamInfo?['url'] as String?;
        print(
            'ENSURE_VIDEO: Got video URL: ${url?.substring(0, 80) ?? 'null'}...');

        if (!mounted || _bgVideoId != videoId) {
          print(
              'ENSURE_VIDEO: Cancelled: mounted=$mounted, currentId=$_bgVideoId');
          _bgVideoLoading = false;
          return;
        }

        if (url == null) {
          print('ENSURE_VIDEO: No video URL found, showing fallback');
          _bgVideoLoading = false;
          if (mounted) setState(() {});
          return;
        }

        print('ENSURE_VIDEO: Creating VideoPlayerController');
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));

        await controller.setLooping(true);
        await controller.setVolume(0);
        print('ENSURE_VIDEO: Initializing controller...');
        await controller.initialize();
        print('ENSURE_VIDEO: Controller initialized: ${controller.value.size}');

        if (!mounted || _bgVideoId != videoId) {
          print('ENSURE_VIDEO: Cancelled after init');
          controller.dispose();
          _bgVideoLoading = false;
          return;
        }

        _bgVideoLoading = false;
        _bgVideoController = controller;
        print('ENSURE_VIDEO: Video ready, calling setState');

        if (mounted) {
          setState(() {});
        }

        await controller.play();
        print('ENSURE_VIDEO: Video playing');
      } catch (e, st) {
        print(
            'ENSURE_VIDEO: Error initializing background video for $videoId: $e');
        print('$st');
        _bgVideoLoading = false;
      }
    }();
  }

  Widget _buildSmartVolumeSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adaptive Audio',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _hasHeadphones,
                    builder: (context, hasHeadphones, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _isCheckingHeadphones,
                        builder: (context, isChecking, _) {
                          if (isChecking) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Detecting headphones...',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Icon(
                                hasHeadphones
                                    ? FluentIcons.headphones_24_filled
                                    : FluentIcons.headphones_24_regular,
                                size: 14,
                                color: hasHeadphones
                                    ? Colors.green
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 6),
                              Text(
                                hasHeadphones
                                    ? 'Headphones connected'
                                    : 'No headphones detected',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: hasHeadphones
                                      ? Colors.green
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _enableSmartVolume,
                builder: (context, isEnabled, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _hasHeadphones,
                    builder: (context, hasHeadphones, _) {
                      return Switch(
                        value: isEnabled,
                        onChanged: hasHeadphones
                            ? (value) {
                                _enableSmartVolume.value = value;
                                if (value) {
                                  _startSmartVolumeAnalysis();
                                } else {
                                  _stopSmartVolumeAnalysis();
                                }
                              }
                            : (value) {
                                // Show dialog when trying to enable without headphones
                                if (value) {
                                  _showNoHeadphonesDialog();
                                }
                              },
                        activeColor: theme.colorScheme.primary,
                      );
                    },
                  );
                },
              ),
            ],
          ),

          // Show warning when no headphones
          ValueListenableBuilder<bool>(
            valueListenable: _hasHeadphones,
            builder: (context, hasHeadphones, _) {
              if (hasHeadphones) return SizedBox.shrink();

              return Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.warning_24_filled,
                      color: Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connect headphones to enable Adaptive Audio',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: _currentEnvironment,
            builder: (context, environment, _) {
              return Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _isAnalyzing,
                    builder: (context, analyzing, _) {
                      return analyzing
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary),
                              ),
                            )
                          : Icon(
                              _getEnvironmentIcon(environment),
                              color: theme.colorScheme.primary,
                              size: 20,
                            );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Environment: $environment',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _confidenceLevel,
                    builder: (context, confidence, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(confidence * 100).round()}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Adaptive Volume Control',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: _currentVolume,
            builder: (context, volume, _) {
              return Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        FluentIcons.speaker_1_24_filled,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: theme.colorScheme.surfaceVariant,
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: volume,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary.withOpacity(0.7),
                                    theme.colorScheme.primary,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(volume * 100).round()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: _enableSmartVolume,
                    builder: (context, enabled, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _hasHeadphones,
                        builder: (context, hasHeadphones, _) {
                          String statusText;
                          if (!hasHeadphones) {
                            statusText =
                                'Connect headphones to enable automatic volume adjustments';
                          } else if (enabled) {
                            statusText =
                                'Automatically adjusting volume based on your environment';
                          } else {
                            statusText =
                                'Enable Adaptive Audio for automatic environment-based adjustments';
                          }

                          return Text(
                            statusText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showVolumeDialog(BuildContext context) {
    final theme = Theme.of(context);
    double tempVolume = _currentVolume.value;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Volume Control'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(FluentIcons.speaker_0_24_regular),
                    Expanded(
                      child: Slider(
                        value: tempVolume,
                        onChanged: (value) {
                          setState(() {
                            tempVolume = value;
                          });
                          audioHandler
                              .customAction('setVolume', {'volume': value});
                        },
                        activeColor: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(FluentIcons.speaker_2_24_filled),
                  ],
                ),
                Text(
                  '${(tempVolume * 100).round()}%',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  IconData _getEnvironmentIcon(String environment) {
    switch (environment.toLowerCase()) {
      case 'music':
        return FluentIcons.music_note_2_24_filled;
      case 'speech':
        return FluentIcons.person_voice_24_filled;
      case 'noise':
        return FluentIcons.speaker_off_24_filled;
      case 'quiet':
        return FluentIcons.speaker_1_24_filled;
      case 'nature':
        return FluentIcons.leaf_one_24_filled;
      default:
        return FluentIcons.sound_wave_circle_24_filled;
    }
  }

  Future<void> _startSmartVolumeAnalysis() async {
    try {
      print('Requesting microphone permission...');
      final permission = await Permission.microphone.request();

      if (permission != PermissionStatus.granted) {
        print('Microphone permission denied: $permission');
        _showPermissionDialog();
        _enableSmartVolume.value = false;
        return;
      }

      print('Microphone permission granted, initializing YAMNet...');
      _yamnetClassifier = YAMNetTFLiteClassifier();
      await _yamnetClassifier!.initialize();

      print('Starting microphone stream...');
      _micStream = await MicStream.microphone(
        audioFormat: AudioFormat.ENCODING_PCM_16BIT,
        sampleRate: 16000,
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
      );

      _micSubscription = _micStream?.listen(
        (audioData) {
          _audioBuffer.add(audioData);

          // Keep more buffers to accumulate enough data
          // 1280 bytes per chunk, need ~25 chunks for 31,200 bytes
          if (_audioBuffer.length > 30) {
            _audioBuffer.removeAt(0);
          }
        },
        onError: (error) {
          debugPrint('Microphone stream error: $error');
        },
        onDone: () {
          print('Microphone stream ended');
        },
      );

      // Start monitoring
      _monitorAudioInput();

      // Analyze every 6 seconds to allow more data accumulation
      _analysisTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
        print('Starting periodic analysis...');
        _analyzeEnvironmentAndAdjustVolume();
      });

      print('Smart Volume Analysis started successfully');
    } catch (e, stackTrace) {
      print('Error starting smart volume analysis: $e');
      print('Stack trace: $stackTrace');
      _enableSmartVolume.value = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start Smart Volume: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _monitorAudioInput() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      if (!_enableSmartVolume.value) {
        timer.cancel();
        return;
      }
    });
  }

  Future<void> _stopSmartVolumeAnalysis() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    _micStream = null;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _audioBuffer.clear();
    // Since YAMNetTFLiteClassifier doesn't have a dispose method, just set it to null.
    _yamnetClassifier = null;

    _currentEnvironment.value = 'Unknown';
    _confidenceLevel.value = 0.0;
    _isAnalyzing.value = false;

    // Reset to base volume smoothly
    _smoothVolumeTransition(_baseVolume);

    debugPrint('Smart Volume Analysis stopped');
  }

  // Add this method to monitor performance
  void _trackAnalysisPerformance(int startTime) {
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final duration = endTime - startTime;

    _analysisCount++;
    _analysisTimes.add(duration.toDouble());

    // Keep only last 10 measurements
    if (_analysisTimes.length > 10) {
      _analysisTimes.removeAt(0);
    }

    // Log performance every 10 analyses
    if (_analysisCount % 10 == 0) {
      final avgTime =
          _analysisTimes.reduce((a, b) => a + b) / _analysisTimes.length;
      debugPrint(
          'Smart Volume Performance: ${avgTime.toStringAsFixed(1)}ms avg over ${_analysisTimes.length} analyses');
    }
  }

  Future<void> _analyzeEnvironmentAndAdjustVolume() async {
    if (_yamnetClassifier == null || _audioBuffer.isEmpty) {
      return;
    }

    final startTime = DateTime.now().millisecondsSinceEpoch;
    _isAnalyzing.value = true;

    try {
      // Combine audio buffers
      final combinedData = <int>[];
      for (final buffer in _audioBuffer) {
        combinedData.addAll(buffer);
      }

      // Calculate how much data we actually need
      const requiredBytes = 31200; // 15600 samples * 2 bytes per sample

      if (combinedData.length < requiredBytes) {
        _isAnalyzing.value = false;
        return;
      }

      // Take the most recent required amount of data
      final audioBytes = Uint8List.fromList(combinedData.length > requiredBytes
          ? combinedData.sublist(combinedData.length - requiredBytes)
          : combinedData);

      final result = await _yamnetClassifier!.classifyAudio(audioBytes);

      // Track performance
      _trackAnalysisPerformance(startTime);

      if (result.isNotEmpty) {
        // PRIORITY CHECK: Look for speech detection first, regardless of confidence
        final speechEntry = result.entries
            .where((entry) => entry.key.toLowerCase() == 'speech')
            .firstOrNull;

        bool isSpeechDetected = false;
        String dominantCategory;
        double dominantConfidence;

        if (speechEntry != null && speechEntry.value > 0.01) {
          // Very low threshold for speech
          // Speech detected - override everything else
          isSpeechDetected = true;
          dominantCategory = 'Speech';
          dominantConfidence = speechEntry.value;
        } else {
          // No speech detected or too low confidence, use normal logic
          final topEntry = result.entries.first;
          dominantCategory = topEntry.key;
          dominantConfidence = topEntry.value;
        }

        _currentEnvironment.value = dominantCategory;
        _confidenceLevel.value = dominantConfidence;

        // Special handling for speech detection
        if (isSpeechDetected) {
          await _adjustVolumeBasedOnEnvironment(
              dominantCategory, dominantConfidence,
              forceSpeechWarning: true);
          _showSpeechDetectionWarning();
        } else {
          await _adjustVolumeBasedOnEnvironment(
              dominantCategory, dominantConfidence);
        }
      }
    } catch (e) {
      // Silently fail to avoid terminal lag during background analysis
    } finally {
      _isAnalyzing.value = false;
    }
  }

  Future<void> _adjustVolumeBasedOnEnvironment(
      String environment, double confidence,
      {bool forceSpeechWarning = false}) async {
    // For speech detection, always proceed regardless of confidence
    if (!forceSpeechWarning && confidence < 0.05) {
      return;
    }

    double volumeMultiplier;
    String adjustmentReason;
    bool shouldRestore = false;

    switch (environment.toLowerCase()) {
      case 'speech':
        volumeMultiplier = 0.15; // Even lower volume for speech detection
        adjustmentReason = forceSpeechWarning
            ? 'Speech detected - emergency volume reduction for conversation'
            : 'Speech detected - dramatically lowering volume for conversation';
        break;
      case 'music':
        volumeMultiplier = 1.0; // Normal volume for music
        adjustmentReason = 'Music detected - maintaining optimal volume';
        shouldRestore = true; // Restore to user's preferred volume
        break;
      case 'noise':
        volumeMultiplier = 0.25; // Very low volume in noisy environments
        adjustmentReason = 'Noisy environment - reducing volume significantly';
        break;
      case 'quiet':
        volumeMultiplier = 1.0; // Return to user's preferred volume when quiet
        adjustmentReason =
            'Quiet environment - restoring to your preferred volume';
        shouldRestore = true; // Restore to user's preferred volume
        break;
      case 'nature':
        volumeMultiplier = 0.6; // Lower for nature sounds
        adjustmentReason = 'Nature sounds - gentle volume reduction';
        break;
      default:
        volumeMultiplier = 1.0;
        adjustmentReason = 'Unknown environment - maintaining current volume';
        shouldRestore = true;
    }

    // Calculate new target volume
    final oldVolume = _targetVolume;

    if (shouldRestore) {
      // Restore to user's original preferred volume
      _targetVolume = _baseVolume;
    } else {
      // For speech, always apply significant reduction regardless of confidence
      if (environment.toLowerCase() == 'speech' && forceSpeechWarning) {
        _targetVolume =
            (_baseVolume * 0.15).clamp(0.05, 1.0); // Emergency speech reduction
      } else {
        // Apply confidence-based scaling with boost for speech detection
        final confidenceScale = confidence.clamp(0.05, 1.0);
        final scalingBoost = environment.toLowerCase() == 'speech' ? 3.0 : 2.0;
        final finalMultiplier =
            1.0 + (volumeMultiplier - 1.0) * confidenceScale * scalingBoost;
        _targetVolume = (_baseVolume * finalMultiplier).clamp(0.10, 1.0);
      }
    }

    // Lower the change threshold to be more responsive, but always adjust for speech
    final shouldAdjust =
        forceSpeechWarning || (oldVolume - _targetVolume).abs() > 0.02;

    if (shouldAdjust) {
      print('🎵 SMART VOLUME ADJUSTMENT 🎵');
      if (forceSpeechWarning) {
        print('🚨 EMERGENCY SPEECH DETECTION - FORCING VOLUME REDUCTION');
      }
      print(
          'Environment: $environment (${(confidence * 100).round()}% confidence)');
      print('Reason: $adjustmentReason');
      print('Base Volume (User Preferred): ${(_baseVolume * 100).round()}%');
      print('Old Volume: ${(oldVolume * 100).round()}%');
      print('New Volume: ${(_targetVolume * 100).round()}%');
      print('Restoring to user preference: $shouldRestore');
      print(
          'Change: ${(((_targetVolume - oldVolume) * 100).round() > 0 ? '+' : '')}${((_targetVolume - oldVolume) * 100).round()}%');

      // Apply smooth volume transition
      _smoothVolumeTransition(_targetVolume);

      // Show visual feedback
      _showVolumeChangeNotification(
          context, environment, _targetVolume, adjustmentReason);
    } else {
      print(
          'Volume change too small (${((oldVolume - _targetVolume).abs() * 100).round()}%), skipping adjustment');
    }
  }

  void _smoothVolumeTransition(double targetVolume) {
    _volumeAnimation = Tween<double>(
      begin: _currentVolume.value,
      end: targetVolume,
    ).animate(CurvedAnimation(
      parent: _volumeAnimationController,
      curve: Curves.easeInOut,
    ))
      ..addListener(() {
        _currentVolume.value = _volumeAnimation.value;
        audioHandler
            .customAction('setVolume', {'volume': _volumeAnimation.value});
      });

    _volumeAnimationController.reset();
    _volumeAnimationController.forward();
  }

  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(FluentIcons.mic_24_filled,
                color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text('Microphone Permission Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Volume needs microphone access to:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• Detect speech and lower volume automatically'),
            Text('• Identify noisy environments'),
            Text('• Adjust volume based on ambient sound'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🔒 Your audio is processed locally on your device and never stored, transmitted, or shared.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _enableSmartVolume.value = false;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Try to request permission again
              final permission = await Permission.microphone.request();
              if (permission.isGranted) {
                _startSmartVolumeAnalysis();
              } else {
                // Open app settings if permission is permanently denied
                await openAppSettings();
              }
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showVolumeChangeNotification(BuildContext context, String environment,
      double targetVolume, String adjustmentReason) {
    if (!mounted) return;

    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getEnvironmentIcon(environment),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Volume adjusted to ${(targetVolume * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    adjustmentReason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 200,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, MediaItem metadata) {
    final theme = Theme.of(context);
    final playlists = userCustomPlaylists.value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playlists.isEmpty)
              const Text('No playlists available. Create one first!')
            else
              ...playlists.map((playlist) {
                return ListTile(
                  title: Text(playlist['title'] ?? 'Untitled Playlist'),
                  subtitle: Text('${playlist['list']?.length ?? 0} songs'),
                  onTap: () async {
                    final audioId = metadata.extras?['ytid'] ?? metadata.id;

                    // Create song object
                    final songMap = {
                      'ytid': audioId,
                      'title': metadata.title,
                      'artist': metadata.artist,
                      'image': metadata.artUri?.toString(),
                      'duration': metadata.duration?.inMilliseconds ?? 0,
                    };

                    final result = addSongInCustomPlaylist(
                      playlist['title'],
                      audioId,
                      songMap,
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );
                  },
                );
              }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsSection(MediaItem meta, ThemeData theme) {
    return SpotifyLyricsView(
      metadata: meta,
      isFullscreen: false,
    );
  }

  Future<List> _fetchLyricVersionSuggestions(
      String title, String artist) async {
    try {
      // Search for similar songs or versions with lyrics
      final suggestions = await fetchSongsList('$title $artist lyrics');

      // Filter and return up to 5 suggestions
      return suggestions.take(5).toList();
    } catch (e) {
      print('Error fetching lyric suggestions: $e');
      return [];
    }
  }

  Widget _buildLyricSuggestions(MediaItem meta, ThemeData theme) {
    return FutureBuilder<List>(
      future: _fetchLyricVersionSuggestions(meta.title, meta.artist ?? ''),
      builder: (context, suggestionSnapshot) {
        if (suggestionSnapshot.connectionState != ConnectionState.done) {
          return const Spinner();
        }
        final suggestions = suggestionSnapshot.data ?? [];
        if (suggestions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          height: 300,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lyric Version Suggestions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return GestureDetector(
                          onTap: () async {
                            await playSuggestedSong(suggestion);
                          },
                          child: Card(
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      suggestion['image'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.music_note),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          suggestion['title'],
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          suggestion['artist'],
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    FluentIcons.music_note_2_24_filled,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ));
                    }),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();

    // Save state before disposing
    _savePlaybackState();

    _stopSmartVolumeAnalysis();
    _stopStateBackup();
  }

  @override
  void deactivate() {
    WidgetsBinding.instance.removeObserver(this);
    super.deactivate();
  }

  // Save current playback state
  Future<void> _savePlaybackState() async {
    final currentMedia = audioHandler.mediaItem.value;
    final currentPosition = audioHandler.playbackState.value.position;
    final isPlaying = audioHandler.playbackState.value.playing;

    if (currentMedia != null) {
      _lastPlaybackState = {
        'songId': currentMedia.extras?['ytid'] ?? currentMedia.id,
        'title': currentMedia.title,
        'artist': currentMedia.artist,
        'artUri': currentMedia.artUri?.toString(),
        'position': currentPosition.inMilliseconds,
        'isPlaying': isPlaying,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'duration': currentMedia.duration?.inMilliseconds ?? 0,
        'extras': currentMedia.extras,
      };

      addOrUpdateData('user', 'lastPlaybackState', _lastPlaybackState);
      print(
          '💾 Playback state saved: ${currentMedia.title} at ${formatDuration(currentPosition.inSeconds)}');
    }
  }

// Load saved playback state
  Future<Map<String, dynamic>?> _loadPlaybackState() async {
    try {
      final data = await getData('user', 'lastPlaybackState');
      if (data != null && data is Map<String, dynamic>) {
        return data;
      }
    } catch (e) {
      print('Error loading playback state: $e');
    }
    return null;
  }

  // Initialize headphone detection
  Future<void> _initializeHeadphoneDetection() async {
    try {
      _isCheckingHeadphones.value = true;

      // Request permissions (Required for Android 12+)
      await _headsetPlugin.requestPermission();

      // Get current headphone state
      final currentState = await _headsetPlugin.getCurrentState;
      _hasHeadphones.value = currentState == HeadsetState.CONNECT;

      print('🎧 Initial headphone state: $currentState');

      // Listen for headphone connect/disconnect events
      _headsetPlugin.setListener((HeadsetState state) {
        print('🎧 Headphone state changed: $state');
        _hasHeadphones.value = state == HeadsetState.CONNECT;

        // Show notification when headphones are connected/disconnected
        _showHeadphoneNotification(state);
      });
    } catch (e) {
      print('❌ Error initializing headphone detection: $e');
      _hasHeadphones.value = false;
    } finally {
      _isCheckingHeadphones.value = false;
    }
  }

  void _showHeadphoneNotification(HeadsetState state) {
    if (!mounted) return;

    final isConnected = state == HeadsetState.CONNECT;
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnected
                  ? FluentIcons.headphones_24_filled
                  : FluentIcons.headphones_24_regular,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isConnected
                    ? 'Headphones connected - Adaptive Audio available'
                    : 'Headphones disconnected - Adaptive Audio disabled',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isConnected ? Colors.green : Colors.orange,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 20,
          right: 20,
        ),
        action: isConnected
            ? SnackBarAction(
                label: 'Enable',
                textColor: Colors.white,
                onPressed: () {
                  if (!_enableSmartVolume.value) {
                    _enableSmartVolume.value = true;
                    _startSmartVolumeAnalysis();
                  }
                },
              )
            : null,
      ),
    );

    // Auto-disable Adaptive Audio when headphones are disconnected
    if (!isConnected && _enableSmartVolume.value) {
      _enableSmartVolume.value = false;
      _stopSmartVolumeAnalysis();
    }
  }

  void _showSpeechDetectionWarning() {
    if (!mounted) return;

    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              FluentIcons.person_voice_24_filled,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🗣️ Speech Detected!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Volume automatically reduced for conversation',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'PRIORITY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600], // Red background for urgency
        duration: Duration(seconds: 4), // Longer duration for speech warnings
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 16,
          right: 16,
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
