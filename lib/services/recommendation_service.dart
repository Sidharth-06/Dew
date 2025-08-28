import 'package:together_ai_sdk/together_ai_sdk.dart';

Future<List<Map<String, String>>> getRecommendationsFromLLM(
    List<Map<String, String>> recentlyPlayed) async {
  TogetherAISdk togetherAISdk = TogetherAISdk('f10fec43af5a4ec8977032825d9e93959d4cabe08b7579602488391a399d914c'); // Replace with your Together AI API key

  final chatResponse = await togetherAISdk.chatCompletion([
    {'role': 'system', 'content': 'You are a helpful AI'},
    {
      'role': 'user',
      'content':
          'Recommend some music similar to these songs: ${recentlyPlayed.map((song) => song['title']).join(', ')}'
    },
  ], ChatModel.llama3Chat8B);

  if (chatResponse != null && chatResponse.choices.isNotEmpty) {
    final recommendations =
        chatResponse.choices[0].message.content.split('\n').map((line) {
      final parts = line.split(' - ');
      return {
        'title': parts[0],
        'artist': parts.length > 1 ? parts[1] : 'Unknown'
      };
    }).toList();
    return recommendations;
  } else {
    throw Exception('Failed to get recommendations');
  }
}
