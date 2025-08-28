import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrendingService {
  static final _yt = YoutubeExplode();
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> updateTrendingVideos() async {
    try {
      // Fetch latest Indian music releases
      final searchQueries = [
        'new tamil songs 2024 official',
        'new hindi songs 2024 official',
        'latest malayalam songs 2024'
      ];

      for (String query in searchQueries) {
        final searchResults = await _yt.search.search(
          query,
          filter: TypeFilters.video,
        );

        // Filter and process videos
        for (var video in searchResults.take(5)) {
          // Check if video already exists
          final existing = await _firestore
              .collection('trending_videos')
              .where('videoUrl', isEqualTo: 'https://youtube.com/watch?v=${video.id.value}')
              .get();

          if (existing.docs.isEmpty) {
            // Add new video
            await _firestore.collection('trending_videos').add({
              'title': video.title,
              'description': video.description,
              'thumbnailUrl': 'https://img.youtube.com/vi/${video.id.value}/maxresdefault.jpg',
              'videoUrl': 'https://youtube.com/watch?v=${video.id.value}',
              'language': query.contains('tamil') ? 'Tamil' : 
                         query.contains('hindi') ? 'Hindi' : 'Malayalam',
              'credits': {
                'channel': video.author,
              },
              'timestamp': FieldValue.serverTimestamp(),
              'viewOrder': 0,
            });
          }
        }
      }
    } catch (e) {
      print('Error updating trending videos: $e');
    }
  }

  static Future<void> updateViewOrder() async {
    // Rotate view order of videos
    final videos = await _firestore
        .collection('trending_videos')
        .orderBy('timestamp', descending: true)
        .limit(15)
        .get();

    int order = 0;
    for (var video in videos.docs) {
      await video.reference.update({'viewOrder': order++});
    }
  }
}