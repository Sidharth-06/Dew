import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MusicService {
  final _yt = YoutubeExplode();

  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    try {
      final searchResults = await _yt.search.search(query);
      return searchResults
          .map((video) => {
                'id': video.id.toString(),
                'title': video.title,
                'thumbnail': video.thumbnails.highResUrl,
              })
          .toList();
    } catch (e) {
      print('Error searching songs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSongDetails(String songId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(songId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      final video = await _yt.videos.get(songId);

      return {
        'id': songId,
        'title': video.title,
        'thumbnail': video.thumbnails.highResUrl,
        'streamUrl': audioStream.url.toString(),
      };
    } catch (e) {
      print('Error getting song details: $e');
      return null;
    }
  }

  void dispose() => _yt.close();
}
