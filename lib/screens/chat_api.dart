import 'package:dew/main.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final YoutubeExplode _yt = YoutubeExplode();

Future<String> searchSongByName(String songName) async {
  try {
    final searchResults = await _yt.search.search(songName);
    final video = searchResults.firstWhere((result) => result is Video);
    return video.id.value;
  } catch (e, stackTrace) {
    logger.log('Error while searching for song by name', e, stackTrace);
    rethrow;
  }
}

Future<AudioOnlyStreamInfo> getSongManifest(String songId) async {
  try {
    final manifest = await _yt.videos.streamsClient.getManifest(songId);
    final audioStream = manifest.audioOnly.withHighestBitrate();
    return audioStream;
  } catch (e, stackTrace) {
    logger.log('Error while getting song streaming manifest', e, stackTrace);
    rethrow;
  }
}
