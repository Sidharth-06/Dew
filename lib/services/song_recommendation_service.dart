import 'package:dew/services/data_manager.dart';

class SongRecommendationService {
  static const String _likedSongsKey = 'liked_songs';
  static const String _playHistoryKey = 'play_history';
  static const String _skippedSongsKey = 'skipped_songs';
  static const String _artistPreferencesKey = 'artist_preferences';
  static const int _maxHistorySize = 100;

  /// Add a song to play history with engagement data
  static Future<void> addToPlayHistory(
    Map<String, dynamic> song, {
    double completionPercentage = 1.0,
  }) async {
    try {
      final history = await getPlayHistory();

      // Add engagement data
      final songWithEngagement = Map<String, dynamic>.from(song);
      songWithEngagement['completionPercentage'] = completionPercentage;
      songWithEngagement['playedAt'] = DateTime.now().toIso8601String();

      history.insert(0, songWithEngagement);

      if (history.length > _maxHistorySize) {
        history.removeRange(_maxHistorySize, history.length);
      }

      addOrUpdateData('user_preferences', _playHistoryKey, history);

      // Update artist preferences
      await _updateArtistPreference(
          song['artist']?.toString() ?? '', completionPercentage);
    } catch (e) {
      print('Error adding to play history: $e');
    }
  }

  /// Track when a user skips a song (negative signal)
  static Future<void> trackSkip(
      Map<String, dynamic> song, double skipPosition) async {
    try {
      final skipped = await _getSkippedSongs();

      final skipData = Map<String, dynamic>.from(song);
      skipData['skipPosition'] = skipPosition;
      skipData['skippedAt'] = DateTime.now().toIso8601String();

      skipped.insert(0, skipData);

      // Keep only recent skips
      if (skipped.length > 50) {
        skipped.removeRange(50, skipped.length);
      }

      addOrUpdateData('user_preferences', _skippedSongsKey, skipped);

      // Negative impact on artist preference
      await _updateArtistPreference(song['artist']?.toString() ?? '', -0.5);
    } catch (e) {
      print('Error tracking skip: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _getSkippedSongs() async {
    try {
      final skipped = await getData(
        'user_preferences',
        _skippedSongsKey,
        defaultValue: [],
      );
      return List<Map<String, dynamic>>.from(skipped ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Update artist preference score
  static Future<void> _updateArtistPreference(
      String artist, double delta) async {
    if (artist.isEmpty) return;

    try {
      final prefs = await getArtistPreferences();
      final normalizedArtist = artist.toLowerCase().trim();

      prefs[normalizedArtist] = (prefs[normalizedArtist] ?? 0.0) + delta;

      // Clamp between -10 and 10
      prefs[normalizedArtist] = prefs[normalizedArtist]!.clamp(-10.0, 10.0);

      addOrUpdateData('user_preferences', _artistPreferencesKey, prefs);
    } catch (e) {
      print('Error updating artist preference: $e');
    }
  }

  /// Get artist preferences (positive = liked, negative = disliked)
  static Future<Map<String, double>> getArtistPreferences() async {
    try {
      final prefs = await getData(
        'user_preferences',
        _artistPreferencesKey,
        defaultValue: <String, dynamic>{},
      );

      if (prefs == null) return {};

      return Map<String, double>.from((prefs as Map)
          .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())));
    } catch (e) {
      print('Error getting artist preferences: $e');
      return {};
    }
  }

  /// Get user's play history
  static Future<List<Map<String, dynamic>>> getPlayHistory() async {
    try {
      final historyRaw = await getData(
        'user_preferences',
        _playHistoryKey,
        defaultValue: [],
      );

      final historyList = (historyRaw as List<dynamic>?) ?? [];
      final normalized = historyList.map<Map<String, dynamic>>((entry) {
        if (entry is Map<String, dynamic>) return entry;
        if (entry is Map) {
          return Map<String, dynamic>.from(entry.map(
            (k, v) => MapEntry(k.toString(), v),
          ));
        }
        return <String, dynamic>{};
      }).toList();

      return normalized;
    } catch (e) {
      print('Error getting play history: $e');
      return [];
    }
  }

  /// Mark a song as liked
  static Future<void> likeSong(Map<String, dynamic> song) async {
    try {
      final likedSongs = await getLikedSongs();

      final exists = likedSongs
          .any((s) => s['id'] == song['id'] || s['ytid'] == song['ytid']);
      if (!exists) {
        likedSongs.add(song);
        addOrUpdateData('user_preferences', _likedSongsKey, likedSongs);

        // Strong positive signal for artist
        await _updateArtistPreference(song['artist']?.toString() ?? '', 2.0);
      }
    } catch (e) {
      print('Error liking song: $e');
    }
  }

  /// Remove a song from liked list
  static Future<void> unlikeSong(String songId) async {
    try {
      final likedSongs = await getLikedSongs();
      final song = likedSongs.firstWhere(
        (s) => s['id'] == songId || s['ytid'] == songId,
        orElse: () => {},
      );

      likedSongs.removeWhere((s) => s['id'] == songId || s['ytid'] == songId);
      addOrUpdateData('user_preferences', _likedSongsKey, likedSongs);

      // Reduce artist preference
      if (song.isNotEmpty) {
        await _updateArtistPreference(song['artist']?.toString() ?? '', -1.0);
      }
    } catch (e) {
      print('Error unliking song: $e');
    }
  }

  /// Get user's liked songs
  static Future<List<Map<String, dynamic>>> getLikedSongs() async {
    try {
      final likedSongs = await getData(
        'user_preferences',
        _likedSongsKey,
        defaultValue: [],
      );
      return List<Map<String, dynamic>>.from(likedSongs ?? []);
    } catch (e) {
      print('Error getting liked songs: $e');
      return [];
    }
  }

  /// Get top preferred artists
  static Future<List<String>> getTopArtists({int limit = 10}) async {
    try {
      final prefs = await getArtistPreferences();
      final sorted = prefs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted
          .where((e) => e.value > 0)
          .take(limit)
          .map((e) => e.key)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Extract genres/tags from song data
  static Set<String> _extractGenres(Map<String, dynamic> song) {
    final genres = <String>{};

    if (song.containsKey('genre')) {
      genres.add(song['genre'].toString().toLowerCase());
    }

    if (song.containsKey('artist')) {
      genres.add(song['artist'].toString().toLowerCase());
    }

    if (song.containsKey('title')) {
      final title = song['title'].toString().toLowerCase();
      if (title.contains('remix')) genres.add('remix');
      if (title.contains('acoustic')) genres.add('acoustic');
      if (title.contains('cover')) genres.add('cover');
      if (title.contains('live')) genres.add('live');
    }

    return genres;
  }

  /// Calculate similarity score between two songs
  static double _calculateSimilarity(
    Map<String, dynamic> song1,
    Map<String, dynamic> song2,
  ) {
    final genres1 = _extractGenres(song1);
    final genres2 = _extractGenres(song2);

    if (genres1.isEmpty || genres2.isEmpty) return 0.0;

    final intersection = genres1.intersection(genres2);
    final union = genres1.union(genres2);

    return intersection.length / union.length;
  }

  /// Get personalized song recommendations based on user preferences
  static Future<List<Map<String, dynamic>>> getRecommendedSongs({
    List<Map<String, dynamic>>? availableSongs,
    int limit = 10,
  }) async {
    try {
      final likedSongs = await getLikedSongs();
      final playHistory = await getPlayHistory();
      final artistPrefs = await getArtistPreferences();
      final skipped = await _getSkippedSongs();

      if (likedSongs.isEmpty && playHistory.isEmpty) {
        return availableSongs?.take(limit).toList() ?? [];
      }

      final userPreferences = <Map<String, dynamic>>[
        ...likedSongs,
        ...playHistory.take(20),
      ];

      final candidates = availableSongs ?? [];

      // Get skipped song IDs to filter out
      final skippedIds = skipped.map((s) => s['ytid'] ?? s['id']).toSet();

      final scoredSongs = candidates.where((song) {
        // Filter out recently skipped songs
        final songId = song['ytid'] ?? song['id'];
        return !skippedIds.contains(songId);
      }).map((song) {
        double score = 0.0;
        int matchCount = 0;

        // Content-based similarity
        for (final pref in userPreferences) {
          if (pref['id'] != song['id'] && pref['ytid'] != song['ytid']) {
            final similarity = _calculateSimilarity(pref, song);
            if (similarity > 0) {
              score += similarity;
              matchCount++;
            }
          }
        }

        // Add artist preference boost
        final artist = song['artist']?.toString().toLowerCase().trim() ?? '';
        if (artist.isNotEmpty && artistPrefs.containsKey(artist)) {
          score += artistPrefs[artist]! * 0.3; // Weight artist preference
        }

        final avgScore = matchCount > 0 ? score / matchCount : score;
        return {
          ...song,
          'score': avgScore,
        };
      }).toList();

      scoredSongs
          .sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));

      return scoredSongs.take(limit).map((song) {
        final copy = Map<String, dynamic>.from(song);
        copy.remove('score');
        return copy;
      }).toList();
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  /// Check if a song is liked
  static Future<bool> isSongLiked(String songId) async {
    try {
      final likedSongs = await getLikedSongs();
      return likedSongs.any((s) => s['id'] == songId || s['ytid'] == songId);
    } catch (e) {
      print('Error checking if song is liked: $e');
      return false;
    }
  }
}
