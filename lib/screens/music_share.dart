import 'package:flutter/material.dart';

class MusicSharePage extends StatelessWidget {
  final dynamic metadata;
  const MusicSharePage({super.key, this.metadata});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Music Sharing temporarily unavailable')),
    );
  }
}
