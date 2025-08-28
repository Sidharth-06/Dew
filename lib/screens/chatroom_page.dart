import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dew/api/musify.dart'; // Your Musify API
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ChatroomPage extends StatefulWidget {
  final String sessionId;
  final bool isHost;

  const ChatroomPage({
    Key? key,
    required this.sessionId,
    this.isHost = false,
  }) : super(key: key);

  @override
  _ChatroomPageState createState() => _ChatroomPageState();
}

class _ChatroomPageState extends State<ChatroomPage> {
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSearching = false;
  final YoutubeExplode _yt = YoutubeExplode();
  String? _username;
  YoutubePlayerController? _ytController;
  StreamSubscription<DocumentSnapshot>? _playbackSubscription;
  StreamSubscription<QuerySnapshot>? _queueSubscription;
  bool _isPlaying = false;
  int _currentPosition = 0;
  bool _isLoadingNext = false;
  String? _currentVideoId; // Track current video ID

  // Add new controller for search results
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;

  // Add this to your _ChatroomPageState class
  bool _isVideoExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    _initializeYoutubePlayer(); // Initialize player here
    _initPlaybackListener();
    _initQueueListener();
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    _queueSubscription?.cancel();
    _ytController?.dispose();
    _messageController.dispose();
    _inputNode.dispose();
    super.dispose();
  }

  Future<void> _fetchUsername() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      setState(() {
        _username = userDoc.data()?['username'] ?? 'Anonymous';
      });
    }
  }

  void _initializeYoutubePlayer() {
    _ytController = YoutubePlayerController(
      initialVideoId: 'dQw4w9WgXcQ', // Dummy video ID
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        forceHD: true,
        startAt: 0,
        controlsVisibleAtStart: true,
        useHybridComposition: true,
      ),
    )..addListener(_youtubeListener);
  }

  void _youtubeListener() {
    if (_ytController!.value.hasError) {
      print('Youtube controller encountered an error');
      // Handle error, maybe try to play next song
    }
  }

  void _initPlaybackListener() {
    _playbackSubscription = _firestore
        .collection('chatrooms')
        .doc(widget.sessionId)
        .collection('songs')
        .doc('currentSong')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        // No current song, pause and clear player
        _ytController?.pause();
        setState(() {
          _currentVideoId = null;
        });
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      _updatePlayerState(data);
    });
  }

  void _initQueueListener() {
    _queueSubscription = _firestore
        .collection('chatrooms')
        .doc(widget.sessionId)
        .collection('queue')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty &&
          _ytController == null &&
          !_isLoadingNext) {
        // If queue is not empty, player is not initialized, and not loading next, play the first song
        _playFirstSongInQueue();
      }
      setState(() {});
    });
  }

  Future<void> _playFirstSongInQueue() async {
    if (_isLoadingNext) return;
    setState(() {
      _isLoadingNext = true;
    });

    try {
      final queueSnapshot = await _firestore
          .collection('chatrooms')
          .doc(widget.sessionId)
          .collection('queue')
          .orderBy('timestamp')
          .limit(1)
          .get();

      if (queueSnapshot.docs.isEmpty) {
        setState(() {
          _isLoadingNext = false;
        });
        return;
      }

      final firstSong = queueSnapshot.docs.first;
      final songData = firstSong.data();

      // Dispose old controller
      _ytController?.dispose();

      // Update Firestore
      await _firestore
          .collection('chatrooms')
          .doc(widget.sessionId)
          .collection('songs')
          .doc('currentSong')
          .set({
        'title': songData['title'],
        'artist': songData['artist'],
        'image': songData['image'],
        'ytId': songData['ytId'],
        'position': 0,
        'isPlaying': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Remove from queue
      await firstSong.reference.delete();

      // Initialize new controller
      final newController = YoutubePlayerController(
        initialVideoId: songData['ytId'],
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
          forceHD: true,
          startAt: 0,
          controlsVisibleAtStart: true,
          useHybridComposition: true,
        ),
      );

      newController.addListener(() {
        if (newController.value.isReady) {
          newController.play();
        }
      });

      setState(() {
        _ytController = newController;
      });

      // Force rebuild after a brief delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ytController?.play();
        }
      });
    } catch (e) {
      print('Error playing first song: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingNext = false;
        });
      }
    }
  }

  void _updatePlayerState(Map<String, dynamic> data) async {
    final videoId = data['ytId'];
    if (videoId == null || videoId == _currentVideoId) return;

    _currentVideoId = videoId; // Update current video ID

    // Load new video
    _ytController?.load(videoId);
  }

  Future<String> fetchSongId(String searchQuery) async {
    try {
      final List<Video> searchResults = await _yt.search.search(searchQuery);
      return searchResults.isNotEmpty ? searchResults.first.id.value : '';
    } catch (e) {
      print('Error fetching song ID: $e');
      return '';
    }
  }

  void _playNextSong() async {
    if (_isLoadingNext) return;
    setState(() {
      _isLoadingNext = true;
    });

    try {
      final queueSnapshot = await _firestore
          .collection('chatrooms')
          .doc(widget.sessionId)
          .collection('queue')
          .orderBy('timestamp')
          .limit(1)
          .get();

      if (queueSnapshot.docs.isEmpty) {
        await _firestore
            .collection('chatrooms')
            .doc(widget.sessionId)
            .collection('songs')
            .doc('currentSong')
            .delete();
        setState(() {
          _currentVideoId = null;
        });
        _ytController?.pause();
        return;
      }

      final nextSong = queueSnapshot.docs.first;
      final songData = nextSong.data();
      final videoId = songData['ytId'];

      // Update Firestore
      await _firestore
          .collection('chatrooms')
          .doc(widget.sessionId)
          .collection('songs')
          .doc('currentSong')
          .set({
        'title': songData['title'],
        'artist': songData['artist'],
        'image': songData['image'],
        'ytId': songData['ytId'],
        'position': 0,
        'isPlaying': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Remove from queue
      await nextSong.reference.delete();

      _ytController?.load(videoId);
      _currentVideoId = videoId;
    } catch (e) {
      print('Error playing next song: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingNext = false;
        });
      }
    }
  }

  Widget _buildQueueList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chatrooms')
          .doc(widget.sessionId)
          .collection('queue')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Queue is empty',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final song =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song['image'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.music_note,
                                  color: Colors.grey[600]),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      song['title'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[800],
            ),
            child: _ytController != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      'https://img.youtube.com/vi/${_ytController!.metadata.videoId}/default.jpg',
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.music_note, color: Colors.white54),
          ),
          const SizedBox(width: 12),

          // Title and controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _ytController?.metadata.title ?? 'No song playing',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        _ytController?.value.isPlaying ?? false
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_ytController?.value.isPlaying ?? false) {
                          _ytController?.pause();
                        } else {
                          _ytController?.play();
                        }
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          SliderTheme(
                            data: SliderThemeData(
                              thumbColor: Colors.blue,
                              activeTrackColor: Colors.blue,
                              inactiveTrackColor: Colors.grey[800],
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 2,
                            ),
                            child: Slider(
                              value: (_ytController?.value.position ?? Duration.zero).inSeconds.toDouble(),
                              max: (_ytController?.metadata.duration ?? Duration.zero).inSeconds.toDouble(),
                              onChanged: (value) {
                                _ytController?.seekTo(Duration(seconds: value.toInt()));
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_ytController?.value.position ?? Duration.zero),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                              Text(
                                _formatDuration(_ytController?.metadata.duration ?? Duration.zero),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expand button
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
            onPressed: () => setState(() => _isVideoExpanded = true),
          ),
        ],
      ),
    );
  }

  // Modify your _buildCompactVideoPlayer to include collapse functionality
  Widget _buildCompactVideoPlayer() {
    return _isVideoExpanded
        ? Column(
            children: [
              Stack(
                children: [
                  // Existing video player code
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _ytController != null
                          ? YoutubePlayer(
                              controller: _ytController!,
                              showVideoProgressIndicator: true,
                              progressIndicatorColor: Colors.blue,
                              progressColors: const ProgressBarColors(
                                playedColor: Colors.blue,
                                handleColor: Colors.blueAccent,
                              ),
                            )
                          : const Center(/* existing placeholder code */),
                    ),
                  ),
                  // Add collapse button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white),
                      onPressed: () => setState(() => _isVideoExpanded = false),
                    ),
                  ),
                ],
              ),
            ],
          )
        : _buildMiniPlayer();
  }

  Widget _buildSearchOverlay() {
    return Container(
      color: Colors.black87,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white24,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchResults.clear();
                      _searchController.clear();
                    });
                  },
                ),
              ),
              onChanged: _handleSearch,
            ),
          ),

          // Search Results
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return Card(
                  color: Colors.white10,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(result['thumbnail'] ?? ''),
                    ),
                    title: Text(
                      result['title'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      result['artist'] ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white70),
                      onPressed: () => _addToQueue(result),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSearch(String query) async {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => _searchResults.clear());
        return;
      }

      try {
        final results = await fetchSongsList(query);
        // Convert the results to the expected format
        final formattedResults = results
            .map((song) => {
                  'title': song['title'],
                  'artist': song['artist'],
                  'thumbnail': song['lowResImage'],
                  'ytId': song['ytid'],
                })
            .toList();
        setState(() => _searchResults = formattedResults);
      } catch (e) {
        print('Search error: $e');
      }
    });
  }

  Future<void> _addToQueue(Map<String, dynamic> song) async {
    try {
      await _firestore
          .collection('chatrooms')
          .doc(widget.sessionId)
          .collection('queue')
          .add({
        'title': song['title'],
        'artist': song['artist'],
        'image': song['thumbnail'],
        'ytId': song['ytId'],
        'addedBy': _auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to queue: ${song['title']}')),
      );
    } catch (e) {
      print('Error adding to queue: $e');
    }
  }

  Widget _buildChatSection() {
    return Container(
      color: Colors.black87, // Dark background
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chatrooms')
                  .doc(widget.sessionId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(), // This will show all messages
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(snapshot.data!.docs[index]);
                  },
                );
              },
            ),
          ),
          Container(
            color: Colors.black, // Dark input area
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _inputNode,
                    style: const TextStyle(color: Colors.white), // White text
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle:
                          TextStyle(color: Colors.grey[400]), // Light grey hint
                      filled: true,
                      fillColor: Colors.grey[900], // Dark grey background
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                            color: Colors.grey[800]!), // Dark grey border
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send,
                      color: Colors.blue), // Blue send icon
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot document) {
    final message = document.data() as Map<String, dynamic>;
    final isCurrentUser = message['userId'] == _auth.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[800],
              child: Text(
                (message['username'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Colors.blue[900]
                    : Colors.grey[800], // Dark message bubbles
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Text(
                      message['username'] ?? 'Anonymous',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue, // Blue username
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    message['text'] ?? '',
                    style: const TextStyle(
                      color: Colors.white, // White message text
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(message['timestamp'] as Timestamp),
                    style: TextStyle(
                      color: Colors.grey[400], // Light grey timestamp
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[800],
              child: Text(
                (_username ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final message = {
        'text': _messageController.text.trim(),
        'userId': _auth.currentUser?.uid,
        'username': _username ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Clear the input field immediately
      _messageController.clear();

      // Add the message to Firestore
      await _firestore
          .collection('chatrooms')
          .doc(widget.sessionId)
          .collection('messages')
          .add(message);

      // Wait for the next frame to ensure ListView is updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController
              .animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          )
              .catchError((error) {
            // Handle any scroll errors silently
            print('Scroll error: $error');
          });
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red[400],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _closeChatroom() async {
    try {
      // Show confirmation dialog
      bool? confirmClose = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Close Chatroom?'),
            content: const Text(
                'Are you sure you want to close this chatroom? This will delete all messages and queue data.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(false); // Return false
                },
              ),
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop(true); // Return true
                },
              ),
            ],
          );
        },
      );

      if (confirmClose == true) {
        // Delete messages
        QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
            .collection('chatrooms')
            .doc(widget.sessionId)
            .collection('messages')
            .get();
        for (var doc in messagesSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete queue
        QuerySnapshot queueSnapshot = await FirebaseFirestore.instance
            .collection('chatrooms')
            .doc(widget.sessionId)
            .collection('queue')
            .get();
        for (var doc in queueSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete current song
        await FirebaseFirestore.instance
            .collection('chatrooms')
            .doc(widget.sessionId)
            .collection('songs')
            .doc('currentSong')
            .delete();

        // Finally, delete the chatroom document itself
        await FirebaseFirestore.instance
            .collection('chatrooms')
            .doc(widget.sessionId)
            .delete();

        // Navigate back
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error closing chatroom: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to close chatroom: $e')),
      );
    }
  }

  Widget _buildJoinRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chatrooms')
          .doc(widget.sessionId)
          .collection('joinRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        // Only show container if there are pending requests
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Returns an empty widget
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900], // Dark theme
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(8.0),
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final request = snapshot.data!.docs[index];
                  final requestData = request.data() as Map<String, dynamic>;

                  return ListTile(
                    title: Text(
                      requestData['username'] ?? 'Unknown User',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _approveJoinRequest(widget.sessionId,
                              request.id, requestData['userId']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () =>
                              _denyJoinRequest(widget.sessionId, request.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _approveJoinRequest(
      String sessionId, String requestId, String userId) async {
    await _firestore
        .collection('chatrooms')
        .doc(sessionId)
        .collection('joinRequests')
        .doc(requestId)
        .update({'status': 'approved'});

    // Add user to approved users
    DocumentReference chatroomRef =
        _firestore.collection('chatrooms').doc(sessionId);
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(chatroomRef);

      if (!snapshot.exists) {
        throw Exception("Chatroom does not exist!");
      }

      List<dynamic> approvedUsers =
          (snapshot.data() as Map<String, dynamic>)['approvedUsers'] ?? [];
      if (!approvedUsers.contains(userId)) {
        approvedUsers.add(userId);
        transaction.update(chatroomRef, {'approvedUsers': approvedUsers});
      }
    });
    setState(() {}); // Refresh the UI
  }

  Future<void> _denyJoinRequest(String sessionId, String requestId) async {
    await _firestore
        .collection('chatrooms')
        .doc(sessionId)
        .collection('joinRequests')
        .doc(requestId)
        .update({'status': 'denied'});
    setState(() {}); // Refresh the UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jam Session'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isSearching = true),
          ),
          if (widget.isHost) // Only show for the host
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _closeChatroom,
            ),
        ],
      ),
      body: Column(
        children: [
          // Video Section (adjust height based on state)
          Container(
            height: _isVideoExpanded
                ? MediaQuery.of(context).size.height * 0.35
                : 70, // Mini player height
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                const BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(child: _buildCompactVideoPlayer()),
                if (_isVideoExpanded) _buildQueueList(),
              ],
            ),
          ),

          // Join Requests Section (For Host Only)
          if (widget.isHost) _buildJoinRequestsList(),

          // Chat Section (65% of screen)
          Expanded(
            child: Stack(
              children: [
                _buildChatSection(),
                if (_isSearching) _buildSearchOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
