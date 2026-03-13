import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/main.dart';
import 'package:dew/services/data_manager.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:dew/services/song_recommendation_service.dart';
import 'package:dew/services/yamnet_classifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});

class PlayerState {
  final VideoPlayerController? videoController;
  final bool isVideoInitialized;
  final bool videoHasMuxedAudio;
  final List<Map<String, dynamic>> recommendedSongs;
  final bool isLoadingRecommendations;
  final bool isAppResumed;
  final String? currentSongId;
  final bool isSeeking;

  /// YAMNet classification cache: mediaId -> top category (Speech/Music/Noise/Quiet/Nature)
  final Map<String, String> yamnetClassification;
  final Map<String, double> yamnetConfidence;

  /// Video fallback state (true when video disabled due to instability)
  final bool videoDisabledFallback;
  final DateTime? videoDisabledUntil;

  PlayerState({
    this.videoController,
    this.isVideoInitialized = false,
    this.videoHasMuxedAudio = false,
    this.recommendedSongs = const [],
    this.isLoadingRecommendations = false,
    this.isAppResumed = true,
    this.currentSongId,
    this.isSeeking = false,
    this.yamnetClassification = const {},
    this.yamnetConfidence = const {},
    this.videoDisabledFallback = false,
    this.videoDisabledUntil,
  });

  PlayerState copyWith({
    VideoPlayerController? videoController,
    bool? isVideoInitialized,
    bool? videoHasMuxedAudio,
    List<Map<String, dynamic>>? recommendedSongs,
    bool? isLoadingRecommendations,
    bool? isAppResumed,
    String? currentSongId,
    bool? isSeeking,
    Map<String, String>? yamnetClassification,
    Map<String, double>? yamnetConfidence,
    bool? videoDisabledFallback,
    DateTime? videoDisabledUntil,
  }) {
    return PlayerState(
      videoController: videoController ?? this.videoController,
      isVideoInitialized: isVideoInitialized ?? this.isVideoInitialized,
      videoHasMuxedAudio: videoHasMuxedAudio ?? this.videoHasMuxedAudio,
      recommendedSongs: recommendedSongs ?? this.recommendedSongs,
      isLoadingRecommendations:
          isLoadingRecommendations ?? this.isLoadingRecommendations,
      isAppResumed: isAppResumed ?? this.isAppResumed,
      currentSongId: currentSongId ?? this.currentSongId,
      isSeeking: isSeeking ?? this.isSeeking,
      yamnetClassification: yamnetClassification ?? this.yamnetClassification,
      yamnetConfidence: yamnetConfidence ?? this.yamnetConfidence,
      videoDisabledFallback:
          videoDisabledFallback ?? this.videoDisabledFallback,
      videoDisabledUntil: videoDisabledUntil ?? this.videoDisabledUntil,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(PlayerState()) {
    _init();
  }

  StreamSubscription? _mediaItemSubscription;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _audioPositionSubscription;
  StreamSubscription? _speedSubscription;
  Timer? _autosaveTimer;
  DateTime? _lastSeekTime;
  bool _isSyncing = false;
  String? _initializingSongId;

  // Seek safety window - if we seek too often we disable video temporarily
  int _recentSeeks = 0;
  DateTime? _seekWindowStart;
  bool _videoDisabledFallback = false;
  DateTime? _videoDisabledUntil;

  // Audio stability tracking (buffering events)
  int _bufferEvents = 0;
  DateTime? _bufferWindowStart;
  static const int _bufferThreshold =
      3; // 3 buffer events within window -> disable video
  static const Duration _bufferWindow = Duration(seconds: 12);
  bool _audioStable =
      true; // Start optimistic; set false when buffering thrashes

  // YAMNet classifier and state
  YAMNetTFLiteClassifier? _yamnetClassifier;
  bool _yamnetInitialized =
      false; // whether initialize() was called successfully
  // Classification cache stored in the Riverpod state (song id -> label/confidence)

  // Fullscreen tracking
  bool _inFullscreen = false;

  // Sync thresholds — relaxed to avoid audio-affecting seeks
  static const int _hardSyncThresholdMs =
      1500; // Force seek only for large drifts (was 500)
  static const int _seekCooldownMs =
      5000; // Long cooldown between hard seeks (was 2000)

  // Disable speed adjustment-based sync (causes artifacts on some devices)
  static const bool _useSpeedAdjust = false;

  void _init() {
    if (!audioHandlerInitialized) {
      logger.log(
          'Audio handler not initialized; skipping player wiring', null, null);
      return;
    }

    _mediaItemSubscription = audioHandler.mediaItem.listen((item) {
      if (item != null) {
        final newId = item.extras?['ytid'] as String?;
        if (newId != null && newId != state.currentSongId) {
          // Tear down any existing video immediately so we don't keep showing
          // the previous track's frames while the new video loads.
          _teardownVideoForTrackChange();
          state = state.copyWith(currentSongId: newId);
          // Only initialize video when user chose the video player style
          if (playerStyleSetting.value == 'video' &&
              !disableVideoForStability.value &&
              !_videoDisabledFallback) {
            initializeVideo(newId);
          }

          // Try to classify the newly loaded track using YAMNet (best-effort).
          _classifyIfPossible(item);
        }
        loadRecommendations();
      }
    });

    _playbackStateSubscription =
        audioHandler.playbackState.listen((playbackState) {
      try {
        // Track buffering events to detect unstable audio
        if (playbackState.processingState == AudioProcessingState.buffering) {
          final now = DateTime.now();
          if (_bufferWindowStart == null ||
              now.difference(_bufferWindowStart!) > _bufferWindow) {
            _bufferWindowStart = now;
            _bufferEvents = 0;
          }
          _bufferEvents++;
          logger.log(
              'PlayerNotifier: buffering event ($_bufferEvents)', null, null);
          _audioStable = false;

          if (_bufferEvents >= _bufferThreshold) {
            logger.log(
                'PlayerNotifier: buffer threshold reached - disabling video fallback',
                null,
                null);
            _disableVideoFallback();
          }

          // Pause video while buffering to prevent desync
          final infoController = state.videoController;
          if (infoController != null && infoController.value.isPlaying) {
            infoController.pause();
          }
          return;
        }

        // When ready, mark stable — but do NOT try to init video here.
        // Video init from playbackState listener caused init attempts during
        // normal buffering→ready transitions which competed for codec resources.
        // Video init is handled only from mediaItem changes.
        if (playbackState.processingState == AudioProcessingState.ready) {
          _bufferEvents = 0;
          _bufferWindowStart = null;
          _audioStable = true;
        }

        final controller = state.videoController;
        if (controller == null || !state.isVideoInitialized) return;

        // Always honor pause, even if audio marked unstable.
        if (!playbackState.playing) {
          if (controller.value.isPlaying) {
            logger.log(
                'PlayerNotifier: playbackState.pause -> pausing video controller',
                null,
                null);
            controller.pause();
          }
          return;
        }

        // If audio unstable, avoid forcing video play actions
        if (!_audioStable) return;

        if (!controller.value.isPlaying) {
          logger.log(
              'PlayerNotifier: playbackState.play -> starting video controller',
              null,
              null);
          controller.play();
        }

        // Adjust volumes based on stream type to avoid audio overlap
        if (playerStyleSetting.value == 'video' && state.isVideoInitialized) {
          if (state.videoHasMuxedAudio) {
            // Muxed stream: video carries audio
            controller.setVolume(1.0);
            audioHandler.audioPlayer.setVolume(0.0);
            logger.log(
                'PlayerNotifier: [PLAYBACK] Muxed stream - video vol 1.0, audio handler vol 0.0',
                null,
                null);
          } else {
            // Video-only stream: audio handler provides audio
            controller.setVolume(0.0);
            audioHandler.audioPlayer.setVolume(1.0);
            logger.log(
                'PlayerNotifier: [PLAYBACK] Video-only stream - video vol 0.0, audio handler vol 1.0',
                null,
                null);
          }
        } else {
          controller.setVolume(0.0);
          audioHandler.audioPlayer.setVolume(1.0);
          logger.log(
              'PlayerNotifier: [PLAYBACK] Non-video style - video vol 0.0, audio handler vol 1.0 (playerStyle=${playerStyleSetting.value}, videoInit=${state.isVideoInitialized})',
              null,
              null);
        }
      } catch (e) {
        logger.log(
            'PlayerNotifier: error handling playbackState change', e, null);
      }
    });

    // Throttled position sync — very relaxed to avoid causing jitter
    _audioPositionSubscription = audioHandler.audioPlayer.positionStream
        .throttleTime(const Duration(milliseconds: 3000))
        .listen((pos) {
      // Only log at debug level; frequent I/O logging itself causes jank
      _onAudioPositionUpdate(pos);
    });

    // Sync playback speed changes
    _speedSubscription = audioHandler.audioPlayer.speedStream.listen((speed) {
      state.videoController?.setPlaybackSpeed(speed);
    });

    // Listen for setting changes
    playerStyleSetting.addListener(_handlePlayerStyleChange);

    // If user opts out of video for stability, react immediately
    disableVideoForStability.addListener(() {
      if (disableVideoForStability.value) {
        logger.log(
            'PlayerNotifier: user requested to disable video for stability',
            null,
            null);
        _disableVideoFallback();
      }
    });

    // Initialize classification storage
    _yamnetClassifier = null;
    _yamnetInitialized = false;

    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      savePlaybackState();
    });
  }

  // Stop and dispose any current video when changing tracks to avoid showing
  // stale frames while the next video loads.
  void _teardownVideoForTrackChange() {
    final controller = state.videoController;
    if (controller != null) {
      try {
        controller.pause();
        controller.dispose();
      } catch (_) {}
    }
    state = state.copyWith(
      videoController: null,
      isVideoInitialized: false,
    );
    _initializingSongId = null;
  }

  // Try to classify the current track using YAMNet when possible.
  Future<void> _classifyIfPossible(MediaItem item) async {
    try {
      final id = item.extras?['ytid'] ?? item.id;
      if (id == null) return;

      // If already classified, skip
      if (state.yamnetClassification.containsKey(id)) return;

      // Best-effort: only handle file:// or .wav resources for now
      final urlStr = item.extras?['url']?.toString();
      if (urlStr == null) return;
      final uri = Uri.tryParse(urlStr);
      if (uri == null) return;

      Uint8List? pcmBytes;

      // Local file path
      if (uri.scheme == 'file' || urlStr.toLowerCase().endsWith('.wav')) {
        final path = uri.scheme == 'file' ? uri.toFilePath() : uri.path;
        final file = File(path);
        if (!await file.exists()) return;
        final bytes = await file.readAsBytes();
        pcmBytes = _extractPcmFromWav(bytes);
      } else if ((uri.isScheme('http') || uri.isScheme('https')) &&
          uri.path.toLowerCase().endsWith('.wav')) {
        // Try a range request for the first N bytes
        final required = (YAMNetTFLiteClassifier.bufferSize * 2);
        final response = await http.get(uri, headers: {
          'Range': 'bytes=0-${required - 1}',
        });
        if (response.statusCode == 206 || response.statusCode == 200) {
          pcmBytes = _extractPcmFromWav(response.bodyBytes);
        } else {
          logger.log(
              'PlayerNotifier: failed to download WAV for classification',
              null,
              null);
          return;
        }
      } else {
        // Not a supported resource for local classification
        logger.log(
            'PlayerNotifier: resource not suitable for YAMNet (need local or .wav)',
            null,
            null);
        return;
      }

      if (pcmBytes == null ||
          pcmBytes.length < YAMNetTFLiteClassifier.bufferSize * 2) {
        logger.log('PlayerNotifier: insufficient PCM data for classification',
            null, null);
        return;
      }

      // Lazily initialize classifier
      if (!_yamnetInitialized) {
        _yamnetClassifier = YAMNetTFLiteClassifier();
        try {
          await _yamnetClassifier!.initialize();
          _yamnetInitialized = true;
        } catch (e) {
          logger.log('PlayerNotifier: failed to initialize YAMNet classifier',
              e, null);
          _yamnetInitialized = false;
          return;
        }
      }

      // Run classification (this is relatively quick for a single-window)
      final sample = pcmBytes.sublist(0, YAMNetTFLiteClassifier.bufferSize * 2);
      final result = await _yamnetClassifier!.classifyAudio(sample);

      if (result.isEmpty) return;

      // Pick top category
      final top = result.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategory = top.first.key;
      final topConfidence = top.first.value;

      // Update state cache
      final newClassMap = Map<String, String>.from(state.yamnetClassification);
      final newConfMap = Map<String, double>.from(state.yamnetConfidence);
      newClassMap[id] = topCategory;
      newConfMap[id] = topConfidence;
      state = state.copyWith(
          yamnetClassification: newClassMap, yamnetConfidence: newConfMap);

      logger.log(
          'PlayerNotifier: YAMNet classified $id as $topCategory (${(topConfidence * 100).toStringAsFixed(1)}%)',
          null,
          null);
    } catch (e, st) {
      logger.log('PlayerNotifier: error during YAMNet classification', e, st);
    }
  }

  Uint8List? _extractPcmFromWav(Uint8List fileBytes) {
    try {
      // Minimal WAV parsing: find "data" chunk and return following bytes
      const dataBytes = [0x64, 0x61, 0x74, 0x61]; // 'data'
      for (int i = 0; i < fileBytes.length - 4; i++) {
        if (fileBytes[i] == dataBytes[0] &&
            fileBytes[i + 1] == dataBytes[1] &&
            fileBytes[i + 2] == dataBytes[2] &&
            fileBytes[i + 3] == dataBytes[3]) {
          final dataStart = i + 8; // skip 'data' + 4-byte length
          if (dataStart >= fileBytes.length) return null;
          final data = fileBytes.sublist(dataStart);
          return Uint8List.fromList(data);
        }
      }
      // Not a standard wav with 'data' chunk; assume raw PCM
      return fileBytes;
    } catch (_) {
      return null;
    }
  }

  void _handlePlayerStyleChange() {
    final controller = state.videoController;

    if (playerStyleSetting.value == 'video') {
      // Video style: audio source depends on whether stream is muxed or video-only
      if (controller != null && state.isVideoInitialized) {
        // Video is ready - muting depends on stream type
        if (state.videoHasMuxedAudio) {
          // Muxed: video has audio, mute handler
          audioHandler.audioPlayer.setVolume(0.0);
        } else {
          // Video-only: audio handler provides audio
          audioHandler.audioPlayer.setVolume(1.0);
        }
      } else {
        // Video not ready yet, keep audio handler unmuted
        audioHandler.audioPlayer.setVolume(1.0);
      }

      if (!disableVideoForStability.value &&
          !_videoDisabledFallback &&
          state.currentSongId != null) {
        initializeVideo(state.currentSongId!);
      }
    } else {
      // Non-video style: mute video, use audio handler sound
      if (controller != null) {
        controller.setVolume(0.0);
      }
      audioHandler.audioPlayer.setVolume(1.0);

      // Optionally dispose video to save resources
      if (controller != null) {
        try {
          controller.dispose();
        } catch (_) {}
        state =
            state.copyWith(videoController: null, isVideoInitialized: false);
      }
    }
  }

  void setIsAppResumed(bool resumed) {
    state = state.copyWith(isAppResumed: resumed);
    final controller = state.videoController;
    if (controller == null) return;

    if (!resumed) {
      // Backgrounding: just pause video and save state. Do NOT seek
      // audio to video position — audio handler is always the source of truth.
      controller.pause();
      savePlaybackState();
    } else {
      if (audioHandler.playbackState.value.playing) {
        // Resuming: gently sync video to audio position without swapping volumes.
        // Keep audio handler audible, video stays muted (unless in fullscreen).
        final audioPos = audioHandler.audioPlayer.position;
        controller.seekTo(audioPos).then((_) {
          if (!_inFullscreen) {
            controller.setVolume(0.0);
          }
          controller.play();
        });
      }
    }
  }

  /// Called on throttled audio position updates - gentle sync
  void _onAudioPositionUpdate(Duration audioPos) {
    if (_isSyncing) return;
    if (!state.isVideoInitialized || state.videoController == null) return;
    if (!audioHandler.playbackState.value.playing) return;
    if (!state.isAppResumed) return;

    // If audio is currently unstable (buffering thrash) or video was disabled as fallback, avoid syncing
    if (!_audioStable || _videoDisabledFallback) {
      logger.log(
          'PlayerNotifier: skipping sync because audio unstable or video disabled',
          null,
          null);
      return;
    }

    final videoPos = state.videoController!.value.position;

    // If we are using the video's audio track in foreground, we don't need to sync-correct
    // because the video IS the source of truth for what the user hears.
    // if (playerStyleSetting.value == 'video') return;
    // ^ COMMENTED OUT: We are now using audioHandler as source of truth always.

    final drift = audioPos.inMilliseconds - videoPos.inMilliseconds;
    final absDrift = drift.abs();

    // Ignore small drifts (most of the time this exits early)
    if (absDrift < _hardSyncThresholdMs) return;

    // Only log significant drifts to reduce I/O overhead
    logger.log(
        'PlayerNotifier: drift ${drift}ms (audio ${audioPos.inMilliseconds} vs video ${videoPos.inMilliseconds})',
        null,
        null);

    // Check buffer - if buffer is low, don't seek to avoid stalls
    final buffered = audioHandler.audioPlayer.bufferedPosition;
    final bufferMs = buffered.inMilliseconds - audioPos.inMilliseconds;
    if (bufferMs < 2000) {
      logger.log('PlayerNotifier: low buffer (${bufferMs}ms), skipping seek',
          null, null);
      return;
    }

    // Prefer hard seek for larger drifts
    if (_useSpeedAdjust) {
      _adjustPlaybackSpeed(drift);
    } else {
      _performHardSeek(audioPos);
    }
  }

  /// Smooth catch-up using playback speed (no visible stutter)
  void _adjustPlaybackSpeed(int driftMs) {
    // Disabled: speed adjustments caused artifacts on low-end devices and networks
    logger.log(
        'PlayerNotifier: _adjustPlaybackSpeed called (drift ${driftMs}ms) - disabled',
        null,
        null);
    return;
  }

  /// Hard seek for large drifts - with cooldown to prevent rapid seeks
  Future<void> _performHardSeek(Duration position) async {
    final now = DateTime.now();
    if (_lastSeekTime != null &&
        now.difference(_lastSeekTime!).inMilliseconds < _seekCooldownMs) {
      logger.log(
          'PlayerNotifier: seek cooldown active; skipping seek', null, null);
      return;
    }

    // If fallback disabled the video due to thrashing, skip seeks
    if (_videoDisabledFallback) {
      if (_videoDisabledUntil != null &&
          DateTime.now().isBefore(_videoDisabledUntil!)) {
        logger.log(
            'PlayerNotifier: video disabled fallback active; skipping seek',
            null,
            null);
        return;
      } else {
        // Re-enable after timeout
        _videoDisabledFallback = false;
        state = state.copyWith(
            videoDisabledFallback: false, videoDisabledUntil: null);
      }
    }

    _isSyncing = true;
    _lastSeekTime = now;

    // Track seeks in a short window
    if (_seekWindowStart == null ||
        now.difference(_seekWindowStart!).inSeconds > 10) {
      _seekWindowStart = now;
      _recentSeeks = 0;
    }
    _recentSeeks++;

    try {
      logger.log(
          'PlayerNotifier: performing hard seek to ${position.inMilliseconds}ms',
          null,
          null);
      // Seek without pausing - smoother experience
      await state.videoController?.seekTo(position);
    } finally {
      _isSyncing = false;
    }

    // If we performed too many seeks quickly, disable video briefly to stabilize audio
    if (_recentSeeks >= 3) {
      _disableVideoFallback();
    }
  }

  void _disableVideoFallback() {
    logger.log('PlayerNotifier: disabling video fallback due to frequent seeks',
        null, null);
    try {
      state.videoController?.dispose();
    } catch (_) {}
    state = state.copyWith(
      videoController: null,
      isVideoInitialized: false,
      videoDisabledFallback: true,
      videoDisabledUntil: DateTime.now().add(const Duration(seconds: 45)),
    );
    _videoDisabledFallback = true;
    _videoDisabledUntil = DateTime.now().add(const Duration(seconds: 45));
    // Restore audio handler as primary sound source
    audioHandler.audioPlayer.setVolume(1.0);
  }

  Future<void> savePlaybackState() async {
    final currentMedia = audioHandler.mediaItem.value;
    final currentPosition = audioHandler.playbackState.value.position;
    final isPlaying = audioHandler.playbackState.value.playing;
    if (currentMedia != null) {
      final playbackState = {
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
      await addOrUpdateData('user', 'lastPlaybackState', playbackState);
    }
  }

  Future<void> initializeVideo(String songId, {bool forceInit = false}) async {
    // Check if we are already initialized for this song
    if (state.currentSongId == songId &&
        state.videoController != null &&
        state.isVideoInitialized) {
      return;
    }

    // If a manual video-disable is set, do not initialize unless forced by UI (e.g., fullscreen request)
    if (disableVideoForStability.value && !forceInit) {
      logger.log(
          'PlayerNotifier: user requested to disable video for stability, skipping init',
          null,
          null);
      return;
    }

    // If user asked for no-video mode, skip initialization
    if (disableVideoForStability.value) {
      logger.log(
          'PlayerNotifier: skipping video init because user disabled video',
          null,
          null);
      return;
    }

    // Stop and hide the old video immediately so the UI doesn't show the wrong video
    // while waiting for the new one to load.
    if (state.isVideoInitialized) {
      state.videoController?.pause();
      state = state.copyWith(isVideoInitialized: false);
    }

    _initializingSongId = songId;

    final oldController = state.videoController;

    try {
      // Fetch stream URL (may be network call) — request highest quality available (up to 2160p/4K)
      // Request max 1080p to avoid buffer overflow on mobile devices
      // Higher resolutions (1440p, 2160p) cause pipeline full errors and video stutter
      final streamInfo = await getVideoStreamUrl(songId, targetQuality: 1080);
      if (streamInfo == null) return;

      final videoUrl = streamInfo['url'] as String?;
      final hasMuxedAudio = streamInfo['hasMuxedAudio'] as bool? ?? false;

      if (videoUrl == null) return;

      // If song changed while fetching (user skipped), abort
      if (state.currentSongId != songId) {
        logger.log(
            'PlayerNotifier: song changed during fetch ($songId -> ${state.currentSongId}), aborting video init',
            null,
            null);
        return;
      }

      // CRITICAL: Set audio handler volume BEFORE initializing video to avoid audio overlap
      // This ensures only one audio source is active during video playback
      if (playerStyleSetting.value == 'video') {
        if (hasMuxedAudio) {
          // Muxed stream: video has embedded audio, mute handler
          await audioHandler.audioPlayer.setVolume(0.0);
          logger.log(
              'PlayerNotifier: [PRE-INIT] Muxed stream - MUTING audio handler before video init',
              null,
              null);
        } else {
          // Video-only stream: unmute handler for audio playback
          await audioHandler.audioPlayer.setVolume(1.0);
          logger.log(
              'PlayerNotifier: [PRE-INIT] Video-only stream - UNMUTING audio handler before video init',
              null,
              null);
        }
        // Small delay to ensure volume change is applied
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          // Disable background playback to reduce pipeline pressure
          // Video should only render when app is in foreground
          allowBackgroundPlayback: false,
        ),
      );

      await controller.initialize();
      await controller.setLooping(false);

      // Set video volume based on mode
      if (playerStyleSetting.value == 'video') {
        // In video mode, let audio handler handle volume unless it's video-only
        await controller.setVolume(hasMuxedAudio ? 1.0 : 0.0);
      } else {
        // In audio-only mode, mute video
        await controller.setVolume(0.0);
      }

      // Sync speed/position to audio handler
      final audioSpeed = audioHandler.audioPlayer.speed;
      await controller.setPlaybackSpeed(audioSpeed);

      final currentAudioPos = audioHandler.audioPlayer.position;
      await controller.seekTo(currentAudioPos);

      // Log the chosen video URL for diagnostics
      logger.log(
          'PlayerNotifier: initialized video controller for $songId with url $videoUrl (max 1080p)',
          null,
          null);
      logger.log(
          'PlayerNotifier: Audio strategy - ${hasMuxedAudio ? 'muxed (video carries audio)' : 'video-only (handler provides audio)'}',
          null,
          null);
      logger.log(
          'PlayerNotifier: Video volume=${controller.value.volume}, Audio handler volume=${audioHandler.audioPlayer.volume}, BackgroundPlayback=false',
          null,
          null);

      // Only start playback if the audio is actually playing.
      // We respect the audio handler's state as the source of truth.
      if (audioHandler.playbackState.value.playing) {
        await controller.play();
      }

      // Atomically swap controller into state to avoid null windows
      state = state.copyWith(
        videoController: controller,
        isVideoInitialized: true,
        videoHasMuxedAudio: hasMuxedAudio,
        currentSongId: songId,
      );

      // Dispose the old controller a bit later to avoid UI race conditions
      if (oldController != null && oldController != controller) {
        Future.delayed(const Duration(milliseconds: 800), () {
          try {
            oldController.dispose();
          } catch (_) {}
        });
      }
    } catch (e) {
      logger.log('Error initializing video in provider', e, null);
    } finally {
      _initializingSongId = null;
    }
  }

  /// Manual seek from UI - sync video immediately
  void seekVideo(Duration position) {
    if (state.videoController == null || !state.isVideoInitialized) return;
    state.videoController!.seekTo(position);
  }

  /// Manual retry (from UI) after video fallback: clear fallback and attempt re-init
  void manualRetryVideoInit() {
    final id = state.currentSongId;
    if (id == null) return;
    _videoDisabledFallback = false;
    _videoDisabledUntil = null;
    state =
        state.copyWith(videoDisabledFallback: false, videoDisabledUntil: null);
    initializeVideo(id, forceInit: true);
  }

  /// Prepare the video controller for fullscreen viewing. Returns true on success.
  Future<bool> prepareFullscreen() async {
    final id = state.currentSongId;
    if (id == null) return false;

    // Ensure we have a controller (force init even if fallback active)
    if (state.videoController == null || !state.isVideoInitialized) {
      await initializeVideo(id, forceInit: true);
    }

    final controller = state.videoController;
    if (controller == null) return false;

    try {
      // Volume strategy for fullscreen depends on stream type
      if (state.videoHasMuxedAudio) {
        // Muxed: video carries audio, mute handler
        await audioHandler.audioPlayer.setVolume(0.0);
        await controller.setVolume(1.0);
        logger.log('PlayerNotifier: fullscreen - muxed stream', null, null);
      } else {
        // Video-only: keep audio handler unmuted for audio
        await controller.setVolume(0.0);
        await audioHandler.audioPlayer.setVolume(1.0);
        logger.log(
            'PlayerNotifier: fullscreen - video-only stream', null, null);
      }

      if (!controller.value.isPlaying) await controller.play();

      _inFullscreen = true;
      return true;
    } catch (e, st) {
      logger.log('PlayerNotifier: error preparing fullscreen', e, st);
      return false;
    }
  }

  /// Exit fullscreen: restore volume routing based on current player style
  Future<void> exitFullscreen() async {
    final controller = state.videoController;
    try {
      if (controller != null) {
        // Restore volume based on stream type
        if (playerStyleSetting.value == 'video' && state.isVideoInitialized) {
          if (state.videoHasMuxedAudio) {
            // Muxed: video carries audio
            await controller.setVolume(1.0);
            await audioHandler.audioPlayer.setVolume(0.0);
            logger.log('PlayerNotifier: exiting fullscreen - muxed stream',
                null, null);
          } else {
            // Video-only: audio handler provides audio
            await controller.setVolume(0.0);
            await audioHandler.audioPlayer.setVolume(1.0);
            logger.log('PlayerNotifier: exiting fullscreen - video-only stream',
                null, null);
          }
        } else {
          // Non-video style: mute video, use audio handler
          await controller.setVolume(0.0);
          await audioHandler.audioPlayer.setVolume(1.0);
        }
      } else {
        // No video controller, just ensure audio handler is audible
        await audioHandler.audioPlayer.setVolume(1.0);
      }
    } catch (e, st) {
      logger.log('PlayerNotifier: error while exiting fullscreen', e, st);
    } finally {
      _inFullscreen = false;
    }
  }

  Future<void> loadRecommendations() async {
    if (state.isLoadingRecommendations) return;
    state = state.copyWith(isLoadingRecommendations: true);

    final availableSongs = audioHandler.queue.value.map((item) {
      String? img = item.artUri?.toString();
      if (img == null || img == 'null' || img.isEmpty) {
        img = item.extras?['artWorkPath']?.toString();
      }
      return {
        'ytid': item.extras?['ytid'] ?? item.id,
        'id': item.id,
        'title': item.title,
        'artist': item.artist,
        'image': img,
        'duration': item.duration?.inMilliseconds ?? 0,
      };
    }).toList();

    // Exclude the currently playing song from recommendation candidates
    final currentId = audioHandler.mediaItem.value?.extras?['ytid'] ??
        audioHandler.mediaItem.value?.id;
    final filteredAvailableSongs = availableSongs.where((s) {
      final sid = s['ytid'] ?? s['id'];
      return sid != currentId;
    }).toList();

    try {
      final recommendationsRaw =
          await SongRecommendationService.getRecommendedSongs(
        availableSongs: filteredAvailableSongs,
        limit: 12,
      );

      // Exclude currently playing and deduplicate by id/ytid
      final currentIdStr = currentId?.toString();
      final seen = <String>{};
      final recommendations = recommendationsRaw
          .where((s) {
            final sid = (s['ytid'] ?? s['id'])?.toString();
            if (sid == null || sid == currentIdStr) return false;
            if (seen.contains(sid)) return false;
            seen.add(sid);
            return true;
          })
          .take(6)
          .toList();

      state = state.copyWith(
          recommendedSongs: recommendations, isLoadingRecommendations: false);
    } catch (e) {
      state = state.copyWith(isLoadingRecommendations: false);
      logger.log('Error loading recommendations in provider', e, null);
    }
  }

  @override
  void dispose() {
    _mediaItemSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _audioPositionSubscription?.cancel();
    _speedSubscription?.cancel();
    _autosaveTimer?.cancel();
    playerStyleSetting.removeListener(_handlePlayerStyleChange);
    state.videoController?.dispose();
    super.dispose();
  }
}
