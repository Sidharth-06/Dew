import 'dart:math';
import 'package:dew/API/musify.dart';
import 'package:dew/services/song_recommendation_service.dart';
import 'package:dew/services/recommendation_service.dart';
import 'package:dew/main.dart';

/// ML-based Music Recommendation Engine
/// Combines multiple strategies for personalized recommendations:
/// 1. Content-based: Similar artists, genres from metadata
/// 2. Collaborative: Based on user play history and likes
/// 3. LLM-based: Smart recommendations from Together AI
class MLRecommendationEngine {
  static final MLRecommendationEngine _instance =
      MLRecommendationEngine._internal();
  factory MLRecommendationEngine() => _instance;
  MLRecommendationEngine._internal();

  // Weights for different recommendation strategies
  static const double _contentWeight = 0.3;
  static const double _collaborativeWeight = 0.4;
  static const double _llmWeight = 0.3;

  // Cache for recommendations to avoid repeated API calls
  List<Map<String, dynamic>> _cachedRecommendations = [];
  DateTime? _lastRecommendationTime;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  /// Get the next recommended song based on current song and user preferences
  Future<Map<String, dynamic>> getNextRecommendation({
    Map<String, dynamic>? currentSong,
    bool useLLM = true,
  }) async {
    try {
      // Check cache first
      if (_isCacheValid() && _cachedRecommendations.isNotEmpty) {
        final recommendation = _cachedRecommendations.removeAt(0);
        logger.log('Using cached recommendation: ${recommendation['title']}',
            null, null);
        return recommendation;
      }

      // Build recommendations from multiple sources
      final recommendations = await _buildRecommendations(
        currentSong: currentSong,
        useLLM: useLLM,
      );

      if (recommendations.isEmpty) {
        return {};
      }

      // Cache the results
      _cachedRecommendations = recommendations.sublist(1);
      _lastRecommendationTime = DateTime.now();

      return recommendations.first;
    } catch (e, stackTrace) {
      logger.log('Error getting ML recommendation', e, stackTrace);
      return {};
    }
  }

  /// Build recommendations from multiple sources
  Future<List<Map<String, dynamic>>> _buildRecommendations({
    Map<String, dynamic>? currentSong,
    bool useLLM = true,
  }) async {
    final List<Map<String, dynamic>> allRecommendations = [];
    final Map<String, double> songScores = {};

    // 1. Content-based recommendations (similar artist/genre)
    try {
      final contentRecs = await _getContentBasedRecommendations(currentSong);
      for (final song in contentRecs) {
        final key = _getSongKey(song);
        songScores[key] = (songScores[key] ?? 0) + _contentWeight;
        if (!allRecommendations.any((s) => _getSongKey(s) == key)) {
          allRecommendations.add(song);
        }
      }
    } catch (e) {
      logger.log('Content-based recommendations failed', e, null);
    }

    // 2. Collaborative recommendations (based on user history)
    try {
      final collaborativeRecs = await _getCollaborativeRecommendations();
      for (final song in collaborativeRecs) {
        final key = _getSongKey(song);
        songScores[key] = (songScores[key] ?? 0) + _collaborativeWeight;
        if (!allRecommendations.any((s) => _getSongKey(s) == key)) {
          allRecommendations.add(song);
        }
      }
    } catch (e) {
      logger.log('Collaborative recommendations failed', e, null);
    }

    // 3. LLM-based recommendations
    if (useLLM) {
      try {
        final llmRecs = await _getLLMRecommendations(currentSong);
        for (final song in llmRecs) {
          final key = _getSongKey(song);
          songScores[key] = (songScores[key] ?? 0) + _llmWeight;
          if (!allRecommendations.any((s) => _getSongKey(s) == key)) {
            allRecommendations.add(song);
          }
        }
      } catch (e) {
        logger.log('LLM recommendations failed', e, null);
      }
    }

    final deduped = _dedupeAndFilter(allRecommendations);
    if (deduped.isEmpty) return [];

    // Sort by combined score to keep strongest signals first
    deduped.sort((a, b) {
      final scoreA = songScores[_getSongKey(a)] ?? 0;
      final scoreB = songScores[_getSongKey(b)] ?? 0;
      return scoreB.compareTo(scoreA);
    });

    // Re-rank using user preferences if available (falls back to the sorted list)
    List<Map<String, dynamic>> personalized = [];
    try {
      personalized = await SongRecommendationService.getRecommendedSongs(
        availableSongs: deduped,
        limit: deduped.length,
      );
    } catch (_) {}

    final ordered = personalized.isNotEmpty ? personalized : deduped;

    // Add some randomness to avoid repetitive recommendations
    _shuffleTopRecommendations(ordered);

    return ordered;
  }

  /// Content-based: Find songs by similar artist or search terms
  Future<List<Map<String, dynamic>>> _getContentBasedRecommendations(
    Map<String, dynamic>? currentSong,
  ) async {
    if (currentSong == null) return [];

    final artist = currentSong['artist']?.toString() ?? '';
    final title = currentSong['title']?.toString() ?? '';

    // Extract key terms from title for similar song search
    final searchTerms = _extractSearchTerms(title, artist);

    final List<Map<String, dynamic>> results = [];

    for (final term in searchTerms.take(2)) {
      try {
        final songs = await fetchSongsList(term);
        for (final song in songs.take(5)) {
          // Don't recommend the same song
          if (song['ytid'] != currentSong['ytid']) {
            results.add(Map<String, dynamic>.from(song));
          }
        }
      } catch (e) {
        // Continue with other terms
      }
    }

    return results;
  }

  /// Collaborative: Based on user's play history and likes
  Future<List<Map<String, dynamic>>> _getCollaborativeRecommendations() async {
    final List<Map<String, dynamic>> results = [];

    // Get user's liked songs and play history
    final likedSongs = await SongRecommendationService.getLikedSongs();
    final playHistory = await SongRecommendationService.getPlayHistory();

    // Extract common artists and genres from user preferences
    final artistCounts = <String, int>{};
    final allSongs = [...likedSongs, ...playHistory.take(20)];

    for (final song in allSongs) {
      final artist = song['artist']?.toString() ?? '';
      if (artist.isNotEmpty) {
        artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      }
    }

    // Get top artists
    final topArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Search for more songs by top artists
    for (final entry in topArtists.take(3)) {
      try {
        final songs = await fetchSongsList(entry.key);
        for (final song in songs.take(5)) {
          final ytid = song['ytid'];
          // Don't recommend songs already in history
          final alreadyPlayed = allSongs.any((s) => s['ytid'] == ytid);
          if (!alreadyPlayed) {
            results.add(Map<String, dynamic>.from(song));
          }
        }
      } catch (e) {
        // Continue with other artists
      }
    }

    return results;
  }

  /// LLM-based: Use Together AI to get smart recommendations
  Future<List<Map<String, dynamic>>> _getLLMRecommendations(
    Map<String, dynamic>? currentSong,
  ) async {
    try {
      // Build context from recent plays
      final playHistory = await SongRecommendationService.getPlayHistory();
      final recentSongs = playHistory.take(5).map((song) {
        return {
          'title': song['title']?.toString() ?? '',
          'artist': song['artist']?.toString() ?? '',
        };
      }).toList();

      if (recentSongs.isEmpty && currentSong != null) {
        recentSongs.add({
          'title': currentSong['title']?.toString() ?? '',
          'artist': currentSong['artist']?.toString() ?? '',
        });
      }

      if (recentSongs.isEmpty) return [];

      // Get LLM recommendations
      final recommendations = await getRecommendationsFromLLM(
        recentSongs.cast<Map<String, String>>(),
      );

      // Search for the recommended songs to get playable versions
      final List<Map<String, dynamic>> results = [];
      for (final rec in recommendations.take(10)) {
        final title = rec['title']?.toString() ?? '';
        final artist = rec['artist']?.toString() ?? '';

        final queries = <String>{
          '$title $artist'.trim(),
          artist,
        }..removeWhere((q) => q.isEmpty);

        for (final query in queries) {
          try {
            final songs = await fetchSongsList(query);
            if (songs.isNotEmpty) {
              final lowerTitle = title.toLowerCase();
              final lowerArtist = artist.toLowerCase();

              final match = songs.firstWhere(
                (s) =>
                    (s['title']?.toString().toLowerCase() ?? '')
                        .contains(lowerTitle) &&
                    (s['artist']?.toString().toLowerCase() ?? '')
                        .contains(lowerArtist),
                orElse: () => songs.first,
              );

              results.add(Map<String, dynamic>.from(match));
              break; // move to next recommendation once we find a playable song
            }
          } catch (e) {
            // Try next query
          }
        }
      }

      return _dedupeAndFilter(results);
    } catch (e) {
      logger.log('LLM recommendation failed', e, null);
      return [];
    }
  }

  /// Extract search terms from song title and artist
  List<String> _extractSearchTerms(String title, String artist) {
    final terms = <String>[];

    // Add artist as primary search term
    if (artist.isNotEmpty) {
      terms.add(artist);
    }

    // Extract meaningful words from title (remove common words)
    final commonWords = {
      'the',
      'a',
      'an',
      'of',
      'in',
      'on',
      'at',
      'to',
      'for',
      'is',
      'are',
      'was',
      'were',
      'and',
      'or',
      'but'
    };
    final titleWords = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((w) => w.length > 2 && !commonWords.contains(w))
        .toList();

    if (titleWords.isNotEmpty) {
      terms.add(titleWords.take(3).join(' '));
    }

    // Add genre-based search if we can detect it
    final genres = _detectGenreFromTitle(title);
    terms.addAll(genres);

    return terms;
  }

  /// Simple genre detection from title keywords
  List<String> _detectGenreFromTitle(String title) {
    final genres = <String>[];
    final lowerTitle = title.toLowerCase();

    final genreKeywords = {
      'pop': ['pop', 'dance', 'party'],
      'rock': ['rock', 'metal', 'guitar'],
      'hip hop': ['rap', 'hip hop', 'trap', 'beat'],
      'electronic': ['edm', 'electronic', 'house', 'techno', 'dj'],
      'classical': ['classical', 'symphony', 'orchestra', 'piano'],
      'jazz': ['jazz', 'blues', 'swing'],
      'country': ['country', 'folk', 'acoustic'],
      'r&b': ['r&b', 'soul', 'rnb'],
      'indian': ['bollywood', 'hindi', 'punjabi', 'tamil', 'telugu'],
    };

    for (final entry in genreKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerTitle.contains(keyword)) {
          genres.add('${entry.key} songs');
          break;
        }
      }
    }

    return genres;
  }

  /// Get unique key for a song
  String _getSongKey(Map<String, dynamic> song) {
    return song['ytid']?.toString() ??
        '${song['title']}_${song['artist']}'.toLowerCase();
  }

  /// Remove incomplete entries and duplicates using id/title/artist
  List<Map<String, dynamic>> _dedupeAndFilter(
      List<Map<String, dynamic>> songs) {
    final seen = <String>{};
    final cleaned = <Map<String, dynamic>>[];

    for (final song in songs) {
      final ytid = (song['ytid'] ?? song['id'] ?? '').toString();
      final title = song['title']?.toString() ?? '';
      final artist = song['artist']?.toString() ?? '';

      if (ytid.isEmpty || title.isEmpty || artist.isEmpty) continue;

      final key = '$ytid|${title.toLowerCase()}|${artist.toLowerCase()}';
      if (seen.add(key)) {
        cleaned.add(Map<String, dynamic>.from(song));
      }
    }

    return cleaned;
  }

  /// Shuffle top recommendations to add variety
  void _shuffleTopRecommendations(List<Map<String, dynamic>> recommendations) {
    if (recommendations.length <= 3) return;

    // Shuffle only the top portion to maintain some relevance order
    final topPortion =
        recommendations.take(min(10, recommendations.length)).toList();
    topPortion.shuffle(Random());

    for (int i = 0; i < topPortion.length; i++) {
      recommendations[i] = topPortion[i];
    }
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_lastRecommendationTime == null) return false;
    return DateTime.now().difference(_lastRecommendationTime!) < _cacheExpiry;
  }

  /// Clear the recommendation cache
  void clearCache() {
    _cachedRecommendations.clear();
    _lastRecommendationTime = null;
  }

  /// Get multiple recommendations at once (for UI display)
  Future<List<Map<String, dynamic>>> getRecommendationBatch({
    Map<String, dynamic>? currentSong,
    int count = 10,
  }) async {
    try {
      final recommendations = await _buildRecommendations(
        currentSong: currentSong,
        useLLM: true,
      );
      return recommendations.take(count).toList();
    } catch (e) {
      logger.log('Error getting recommendation batch', e, null);
      return [];
    }
  }
}

// Global instance for easy access
final mlRecommendationEngine = MLRecommendationEngine();
