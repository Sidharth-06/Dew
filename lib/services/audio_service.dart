/*
 *     Copyright (C) 2024 Valeri Gokadze
 *
 *     dew is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     dew is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about dew, including how to contribute,
 *     please visit: https://github.com/gokadzev/dew
 */

import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/main.dart';
import 'package:dew/models/position_data.dart';
import 'package:dew/services/data_manager.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:dew/utilities/mediaitem.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dew/services/song_recommendation_service.dart';
import 'package:dew/services/ml_recommendation_engine.dart';

class MusifyAudioHandler extends BaseAudioHandler {
  MusifyAudioHandler() {
    _setupEventSubscriptions();
    _updatePlaybackState();

    _initialize();
  }

  // Use AudioPlayer with proper settings for background playback
  AudioPlayer audioPlayer = AudioPlayer(
    // Handle audio becoming noisy (e.g., headphones unplugged)
    handleAudioSessionActivation: false,
    androidApplyAudioAttributes: true,
    handleInterruptions: false, // We handle interruptions ourselves
    audioPipeline: AudioPipeline(
      androidAudioEffects: [],
    ),
  );

  late StreamSubscription<PlaybackEvent> _playbackEventSubscription;
  late StreamSubscription<Duration?> _durationSubscription;
  late StreamSubscription<int?> _currentIndexSubscription;
  late StreamSubscription<SequenceState?> _sequenceStateSubscription;

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        audioPlayer.positionStream,
        audioPlayer.bufferedPositionStream,
        audioPlayer.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );

  final processingStateMap = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  final repeatModeMap = {
    LoopMode.off: AudioServiceRepeatMode.none,
    LoopMode.one: AudioServiceRepeatMode.one,
    LoopMode.all: AudioServiceRepeatMode.all,
  };

  void _handlePlaybackEvent(PlaybackEvent event) {
    try {
      logger.log(
          'AudioHandler: playback event state=${event.processingState} pos=${audioPlayer.position.inMilliseconds}',
          null,
          null);
      if (event.processingState == ProcessingState.buffering) {
        logger.log('AudioHandler: buffering...', null, null);
      }

      // Check if song completed - remove audioPlayer.playing check as it may be false on completion
      if (event.processingState == ProcessingState.completed) {
        // Check repeat mode first
        if (audioPlayer.loopMode == LoopMode.one) {
          // Repeat current song
          audioPlayer.seek(Duration.zero);
          audioPlayer.play();
        } else if (hasNext) {
          // Play next song in playlist
          skipToNext();
        } else if (playNextSongAutomatically.value) {
          // No next song in playlist, get a similar/recommended song
          getRandomSong().then((song) {
            if (song.isNotEmpty) {
              playSong(song);
            }
          });
        }
        // If none of the above, playback stops naturally
      }
      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error handling playback event', e, stackTrace);
    }
  }

  void _handleDurationChange(Duration? duration) {
    try {
      final index = audioPlayer.currentIndex;
      if (index != null && queue.value.isNotEmpty) {
        final newQueue = List<MediaItem>.from(queue.value);
        final oldMediaItem = newQueue[index];
        final newMediaItem = oldMediaItem.copyWith(duration: duration);
        newQueue[index] = newMediaItem;
        queue.add(newQueue);
        mediaItem.add(newMediaItem);
      }
    } catch (e, stackTrace) {
      logger.log('Error handling duration change', e, stackTrace);
    }
  }

  void _handleCurrentSongIndexChanged(int? index) {
    try {
      if (index != null && queue.value.isNotEmpty) {
        final playlist = queue.value;
        mediaItem.add(playlist[index]);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error handling current song index change',
        e,
        stackTrace,
      );
    }
  }

  void _handleSequenceStateChange(SequenceState? sequenceState) {
    try {
      final sequence = sequenceState?.effectiveSequence;
      if (sequence != null && sequence.isNotEmpty) {
        final items =
            sequence.map((source) => source.tag as MediaItem).toList();
        queue.add(items);
        shuffleNotifier.value = sequenceState?.shuffleModeEnabled ?? false;
      }
    } catch (e, stackTrace) {
      logger.log('Error handling sequence state change', e, stackTrace);
    }
  }

  void _setupEventSubscriptions() {
    _playbackEventSubscription =
        audioPlayer.playbackEventStream.listen(_handlePlaybackEvent);
    _durationSubscription =
        audioPlayer.durationStream.listen(_handleDurationChange);
    _currentIndexSubscription =
        audioPlayer.currentIndexStream.listen(_handleCurrentSongIndexChanged);
    _sequenceStateSubscription =
        audioPlayer.sequenceStateStream.listen(_handleSequenceStateChange);
  }

  // Add debouncing for frequent updates
  Timer? _updateTimer;
  PlaybackState? _lastEmittedState;

  void _updatePlaybackState() {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 150), () {
      final newState = PlaybackState(
        controls: [
          if (hasPrevious || hasNext)
            MediaControl.skipToPrevious
          else
            MediaControl.rewind,
          if (audioPlayer.playing) MediaControl.pause else MediaControl.play,
          if (hasPrevious || hasNext)
            MediaControl.skipToNext
          else
            MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingStateMap[audioPlayer.processingState]!,
        repeatMode: repeatModeMap[audioPlayer.loopMode]!,
        shuffleMode: audioPlayer.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        playing: audioPlayer.playing,
        updatePosition: audioPlayer.position,
        bufferedPosition: audioPlayer.bufferedPosition,
        speed: audioPlayer.speed,
        queueIndex: audioPlayer.currentIndex ?? 0,
      );

      // Only emit if state actually changed meaningfully
      if (_lastEmittedState == null ||
          _lastEmittedState!.playing != newState.playing ||
          _lastEmittedState!.processingState != newState.processingState ||
          _lastEmittedState!.queueIndex != newState.queueIndex) {
        _lastEmittedState = newState;
        playbackState.add(newState);
      }
    });
  }

  Future<void> _initialize() async {
    final session = await AudioSession.instance;
    try {
      // Enhanced audio session configuration for background playback
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      // Activate session immediately
      await session.setActive(true);

      // Handle becoming noisy (headphones unplugged)
      session.becomingNoisyEventStream.listen((_) {
        audioPlayer.pause();
      });

      // Handle audio interruptions (calls, other apps, etc.)
      session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Lower volume temporarily instead of pausing
              await audioPlayer.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
              _wasPlayingBeforeInterruption = audioPlayer.playing;
              await audioPlayer.pause();
              break;
            case AudioInterruptionType.unknown:
              _wasPlayingBeforeInterruption = audioPlayer.playing;
              await audioPlayer.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Restore volume
              await audioPlayer.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              // Only resume if we were playing before interruption
              if (_wasPlayingBeforeInterruption) {
                // Small delay to let the system settle
                await Future.delayed(const Duration(milliseconds: 300));
                await audioPlayer.play();
              }
              break;
            case AudioInterruptionType.unknown:
              // Don't auto-resume for unknown interruptions
              break;
          }
        }
      });

      // Log audio device changes but do NOT pause/resume \u2014 previous logic\n      // caused audible gaps every time Bluetooth state changed.\n      session.devicesChangedEventStream.listen((event) {\n        logger.log('AudioSession: device change detected', null, null);\n      });
    } catch (e, stackTrace) {
      logger.log('Error initializing audio session', e, stackTrace);
    }
  }

  bool _wasPlayingBeforeInterruption = false;

  @override
  Future<void> onTaskRemoved() async {
    await audioPlayer.stop().then((_) => audioPlayer.dispose());

    await _playbackEventSubscription.cancel();
    await _durationSubscription.cancel();
    await _currentIndexSubscription.cancel();
    await _sequenceStateSubscription.cancel();

    await super.onTaskRemoved();
  }

  bool get hasNext => activePlaylist['list'].isEmpty
      ? audioPlayer.hasNext
      : activeSongId + 1 < activePlaylist['list'].length;

  bool get hasPrevious => activePlaylist['list'].isEmpty
      ? audioPlayer.hasPrevious
      : activeSongId > 0;

  @override
  Future<void> play() => audioPlayer.play();
  @override
  Future<void> pause() => audioPlayer.pause();
  @override
  Future<void> stop() => audioPlayer.stop();
  @override
  Future<void> seek(Duration position) => audioPlayer.seek(position);

  @override
  Future<void> fastForward() =>
      seek(Duration(seconds: audioPlayer.position.inSeconds + 15));

  @override
  Future<void> rewind() =>
      seek(Duration(seconds: audioPlayer.position.inSeconds - 15));

  Future<void> playSong(Map song, {bool play = true}) async {
    try {
      final isOffline = song['isOffline'] ?? false;
      final ytid = song['ytid'];
      final isLive = song['isLive'] ?? false;

      String? songUrl;

      // Attempt 1: Try with cached URL
      try {
        if (isOffline) {
          songUrl = song['audioPath'];
        } else {
          songUrl = await getSong(ytid, isLive);
        }

        if (songUrl == null) throw Exception('Failed to get song URL');
        logger.log(
            '▶️ playSong: Got URL, building audio source...', null, null);

        final audioSource = await buildAudioSource(song, songUrl, isOffline);
        logger.log('▶️ playSong: Setting audio source...', null, null);
        // Preload for smoother playback
        await audioPlayer.setAudioSource(audioSource, preload: true);
        if (play) {
          logger.log('▶️ playSong: Starting playback...', null, null);
          await audioPlayer.play();
        }
      } catch (e) {
        if (isOffline) rethrow; // Don't retry offline files

        logger.log('Error playing song (Attempt 1), retrying with fresh URL...',
            e, null);

        // Attempt 2: Retry with Force Refresh
        songUrl = await getSong(ytid, isLive, forceRefresh: true);
        if (songUrl == null) throw Exception('Failed to get fresh song URL');

        final audioSource = await buildAudioSource(song, songUrl, isOffline);
        // Preload for smoother playback
        await audioPlayer.setAudioSource(audioSource, preload: true);
        if (play) {
          await audioPlayer.play();
        }

        // Track play history for recommendations
        SongRecommendationService.addToPlayHistory(
            Map<String, dynamic>.from(song));
      }
    } catch (e, stackTrace) {
      logger.log('Error playing song', e, stackTrace);
    }
  }

  Future<void> playPlaylistSong({
    Map<dynamic, dynamic>? playlist,
    required int songIndex,
  }) async {
    if (playlist != null) activePlaylist = playlist;
    activeSongId = songIndex;
    await audioHandler.playSong(activePlaylist['list'][activeSongId]);
  }

  Future<AudioSource> buildAudioSource(
    Map song,
    String songUrl,
    bool isOffline,
  ) async {
    final uri = Uri.parse(songUrl);
    final tag = mapToMediaItem(song, songUrl);
    final audioSource = AudioSource.uri(
      uri,
      tag: tag,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      },
    );

    if (isOffline || !sponsorBlockSupport.value) {
      return audioSource;
    }

    final spbAudioSource =
        await checkIfSponsorBlockIsAvailable(audioSource, song['ytid']);
    return spbAudioSource ?? audioSource;
  }

  Future<ClippingAudioSource?> checkIfSponsorBlockIsAvailable(
    UriAudioSource audioSource,
    String songId,
  ) async {
    try {
      final segments = await getSkipSegments(songId);

      if (segments.isNotEmpty) {
        final start = Duration(seconds: segments[0]['end']!);
        final end = segments.length > 1
            ? Duration(seconds: segments[1]['start']!)
            : null;

        return end != null && end != Duration.zero && start < end
            ? ClippingAudioSource(
                child: audioSource,
                start: start,
                end: end,
                tag: audioSource.tag,
              )
            : null;
      }
    } catch (e, stackTrace) {
      logger.log('Error checking sponsor block', e, stackTrace);
    }
    return null;
  }

  Future<void> skipToSong(int newIndex) async {
    if (newIndex >= 0 && newIndex < activePlaylist['list'].length) {
      activeSongId = shuffleNotifier.value
          ? _generateRandomIndex(activePlaylist['list'].length)
          : newIndex;

      await playSong(activePlaylist['list'][activeSongId]);
    }
  }

  @override
  Future<void> skipToNext() async {
    final nextIndex = activeSongId + 1;
    if (nextIndex >= 0 && nextIndex < activePlaylist['list'].length) {
      await skipToSong(nextIndex);
      return;
    }

    // No next in playlist - fall back to a recommended/random song
    final song = await getRandomSong();
    if (song.isNotEmpty) {
      await playSong(song);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final prevIndex = activeSongId - 1;
    if (prevIndex >= 0 && prevIndex < activePlaylist['list'].length) {
      await skipToSong(prevIndex);
      return;
    }

    // No previous in playlist - fall back to a recommended/random song
    final song = await getRandomSong();
    if (song.isNotEmpty) {
      await playSong(song);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final shuffleEnabled = shuffleMode != AudioServiceShuffleMode.none;
    shuffleNotifier.value = shuffleEnabled;
    await audioPlayer.setShuffleModeEnabled(shuffleEnabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final repeatEnabled = repeatMode != AudioServiceRepeatMode.none;
    repeatNotifier.value = repeatEnabled as AudioServiceRepeatMode;
    await audioPlayer.setLoopMode(repeatEnabled ? LoopMode.one : LoopMode.off);
  }

  void changeSponsorBlockStatus() {
    sponsorBlockSupport.value = !sponsorBlockSupport.value;
    addOrUpdateData(
      'settings',
      'sponsorBlockSupport',
      sponsorBlockSupport.value,
    );
  }

  void changeAutoPlayNextStatus() {
    playNextSongAutomatically.value = !playNextSongAutomatically.value;
    addOrUpdateData(
      'settings',
      'playNextSongAutomatically',
      playNextSongAutomatically.value,
    );
  }

  int _generateRandomIndex(int length) {
    final random = Random();
    var randomIndex = random.nextInt(length);

    while (randomIndex == activeSongId) {
      randomIndex = random.nextInt(length);
    }

    return randomIndex;
  }

  // Queue implementation
  final BehaviorSubject<List<MediaItem>> queue =
      BehaviorSubject<List<MediaItem>>.seeded([]);
  final BehaviorSubject<MediaItem?> mediaItem =
      BehaviorSubject<MediaItem?>.seeded(null);

  // Active playlist management
  Map<dynamic, dynamic> activePlaylist = {'list': []};
  int activeSongId = 0;

  Future<Map> getRandomSong() async {
    try {
      // Get current song info for context
      final currentSong = mediaItem.value;
      Map<String, dynamic>? currentSongMap;

      if (currentSong != null) {
        currentSongMap = {
          'title': currentSong.title,
          'artist': currentSong.artist,
          'ytid': currentSong.extras?['ytid'] ?? currentSong.id,
        };
      }

      // Strategy 1: Use ML Recommendation Engine (combines LLM + collaborative + content-based)
      try {
        final mlRecommendation =
            await mlRecommendationEngine.getNextRecommendation(
          currentSong: currentSongMap,
          useLLM: true,
        );
        if (mlRecommendation.isNotEmpty) {
          logger.log('Using ML recommendation: ${mlRecommendation['title']}',
              null, null);
          return mlRecommendation;
        }
      } catch (e) {
        logger.log('ML recommendation failed, trying fallbacks', e, null);
      }

      // Strategy 2: YouTube similar videos
      if (currentSongMap != null) {
        final ytId = currentSongMap['ytid'];
        if (ytId != null && ytId.isNotEmpty) {
          await getSimilarSong(ytId);
          if (nextRecommendedSong != null &&
              nextRecommendedSong is Map &&
              (nextRecommendedSong as Map).isNotEmpty) {
            final song = Map<dynamic, dynamic>.from(nextRecommendedSong);
            nextRecommendedSong = null;
            logger.log('Using YouTube similar: ${song['title']}', null, null);
            return song;
          }
        }
      }

      // Strategy 3: Generic recommendations from API
      final recommendations = await getRecommendedSongs(true);
      if (recommendations.isNotEmpty) {
        // Avoid returning the currently playing song
        final filteredRecs = recommendations.where((r) {
          final ry = r['ytid'] ?? r['id'];
          return ry?.toString() != currentSongMap?['ytid']?.toString();
        }).toList();
        if (filteredRecs.isNotEmpty) {
          final randomIndex = Random().nextInt(filteredRecs.length);
          logger.log('Using generic recommendation', null, null);
          return Map<dynamic, dynamic>.from(filteredRecs[randomIndex]);
        }
      }

      // No recommendations available
      logger.log('No recommendations available', null, null);
      return {};
    } catch (e, stackTrace) {
      logger.log('Error getting random song', e, stackTrace);
      return {};
    }
  }

  void dispose() {
    _updateTimer?.cancel();
    queue.close();
    mediaItem.close();
  }
}
