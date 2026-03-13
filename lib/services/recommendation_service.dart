import 'package:together_ai_sdk/together_ai_sdk.dart';
import 'package:dew/services/song_recommendation_service.dart';
import 'package:dew/main.dart';

// Use environment variable or secure storage in production
const String _togetherApiKey =
    'f10fec43af5a4ec8977032825d9e93959d4cabe08b7579602488391a399d914c';

/// Get music recommendations from LLM based on recently played songs
/// Returns a list of {title, artist} maps
Future<List<Map<String, String>>> getRecommendationsFromLLM(
    List<Map<String, String>> recentlyPlayed) async {
  try {
    final togetherAISdk = TogetherAISdk(_togetherApiKey);

    // Build a detailed prompt with user preferences
    final songList = recentlyPlayed
        .map((song) => '- "${song['title']}" by ${song['artist']}')
        .join('\n');

    // Get user's liked songs for additional context
    final likedSongs = await SongRecommendationService.getLikedSongs();
    final likedArtists = likedSongs
        .map((s) => s['artist']?.toString())
        .where((a) => a != null && a.isNotEmpty)
        .toSet()
        .take(5)
        .join(', ');

    final systemPrompt =
        '''You are a music recommendation AI. Your task is to recommend songs similar to what the user has been listening to.

Rules:
1. Recommend exactly 10 songs
2. Format each recommendation as: Song Title - Artist Name
3. One recommendation per line
4. Do not include numbering or bullet points
5. Recommend real, popular songs that can be found on YouTube
6. Mix recommendations between similar genres and artists the user might like
7. Include both well-known hits and hidden gems''';

    final userPrompt = '''Based on these recently played songs:
$songList

${likedArtists.isNotEmpty ? 'The user also likes these artists: $likedArtists' : ''}

Recommend 10 similar songs they might enjoy:''';

    final chatResponse = await togetherAISdk.chatCompletion([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ], ChatModel.llama3Chat8B);

    if (chatResponse.choices.isNotEmpty) {
      final content = chatResponse.choices[0].message.content;
      final recommendations = _parseRecommendations(content);

      logger.log(
          'LLM returned ${recommendations.length} recommendations', null, null);
      return recommendations;
    } else {
      throw Exception('Empty response from LLM');
    }
  } catch (e) {
    logger.log('LLM recommendation error: $e', null, null);
    // Return empty list instead of throwing to allow fallback
    return [];
  }
}

/// Parse LLM response into structured recommendations
List<Map<String, String>> _parseRecommendations(String content) {
  final recommendations = <Map<String, String>>[];

  final lines = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  for (final line in lines) {
    // Remove common prefixes like "1.", "- ", "* ", etc.
    String cleanLine = line
        .replaceAll(RegExp(r'^[\d]+[.)\s]+'), '')
        .replaceAll(RegExp(r'^[-*•]\s*'), '')
        .trim();

    // Try to parse "Song Title - Artist" format
    if (cleanLine.contains(' - ')) {
      final parts = cleanLine.split(' - ');
      if (parts.length >= 2) {
        recommendations.add({
          'title': parts[0].replaceAll('"', '').trim(),
          'artist': parts.sublist(1).join(' - ').replaceAll('"', '').trim(),
        });
      }
    }
    // Try "Song Title by Artist" format
    else if (cleanLine.toLowerCase().contains(' by ')) {
      final parts = cleanLine.toLowerCase().split(' by ');
      if (parts.length >= 2) {
        recommendations.add({
          'title': _capitalizeTitle(parts[0].replaceAll('"', '').trim()),
          'artist': _capitalizeTitle(
              parts.sublist(1).join(' by ').replaceAll('"', '').trim()),
        });
      }
    }
  }

  return recommendations;
}

/// Capitalize title properly
String _capitalizeTitle(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}

/// Get mood-based recommendations
Future<List<Map<String, String>>> getMoodBasedRecommendations(
    String mood) async {
  try {
    final togetherAISdk = TogetherAISdk(_togetherApiKey);

    final systemPrompt =
        '''You are a music recommendation AI specializing in mood-based suggestions.

Rules:
1. Recommend exactly 10 songs
2. Format: Song Title - Artist Name
3. One recommendation per line
4. All songs should match the requested mood
5. Include a mix of genres within that mood''';

    final userPrompt = 'Recommend 10 songs for a $mood mood:';

    final chatResponse = await togetherAISdk.chatCompletion([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ], ChatModel.llama3Chat8B);

    if (chatResponse.choices.isNotEmpty) {
      return _parseRecommendations(chatResponse.choices[0].message.content);
    }
    return [];
  } catch (e) {
    logger.log('Mood-based recommendation error: $e', null, null);
    return [];
  }
}

/// Get genre-based recommendations
Future<List<Map<String, String>>> getGenreBasedRecommendations(
    String genre) async {
  try {
    final togetherAISdk = TogetherAISdk(_togetherApiKey);

    final systemPrompt =
        '''You are a music expert with deep knowledge of all genres.

Rules:
1. Recommend exactly 10 songs
2. Format: Song Title - Artist Name
3. One recommendation per line
4. All songs should be from the requested genre
5. Mix classic hits with newer releases''';

    final userPrompt = 'Recommend 10 great $genre songs:';

    final chatResponse = await togetherAISdk.chatCompletion([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ], ChatModel.llama3Chat8B);

    if (chatResponse.choices.isNotEmpty) {
      return _parseRecommendations(chatResponse.choices[0].message.content);
    }
    return [];
  } catch (e) {
    logger.log('Genre-based recommendation error: $e', null, null);
    return [];
  }
}
