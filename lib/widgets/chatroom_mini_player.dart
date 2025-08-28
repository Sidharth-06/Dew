import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class ChatroomMiniPlayer extends StatelessWidget {
  final String songId;
  final String songName;
  final String thumbnail;
  final bool isHost;
  final AudioPlayer audioPlayer;
  final VoidCallback? onStop;

  const ChatroomMiniPlayer({
    Key? key,
    required this.songId,
    required this.songName,
    required this.thumbnail,
    required this.isHost,
    required this.audioPlayer,
    this.onStop, required String currentSongId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: EdgeInsets.all(8),
      color: Colors.grey[900],
      child: Row(
        children: [
          Image.network(thumbnail, width: 50, height: 50),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              songName,
              style: TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isHost) ...[
            IconButton(
              icon: Icon(Icons.stop, color: Colors.white),
              onPressed: onStop,
            ),
          ],
        ],
      ),
    );
  }
}
