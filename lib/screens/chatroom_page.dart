import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:dew/config/appwrite_config.dart';
import 'package:dew/services/appwrite_service.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dew/api/musify.dart'; // Your Musify API
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/core/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
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
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSearching = false;
  final YoutubeExplode _yt = YoutubeExplode();
  String? _username;
  String? _userId;
  YoutubePlayerController? _ytController;
  RealtimeSubscription? _realtimeSubscription;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _joinRequests = [];
  // StreamSubscription<DocumentSnapshot>? _playbackSubscription;
  // StreamSubscription<QuerySnapshot>? _queueSubscription;
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
    // Initialize Realtime listener
    _initRealtime();
    // Load initial data (optional, or rely on realtime if persisted)
    // _loadInitialData();
  }

  @override
  void dispose() {
    _realtimeSubscription?.close();
    _ytController?.dispose();
    _messageController.dispose();
    _inputNode.dispose();
    super.dispose();
  }

  Future<void> _fetchUsername() async {
    try {
      final user = await AppwriteService().account.get();
      _userId = user.$id;
      final userDoc = await AppwriteService().databases.getDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'users',
            documentId: user.$id,
          );
      setState(() {
        _username = userDoc.data['username'] ?? user.name;
      });
    } catch (e) {
      print('Error fetching username: $e');
      setState(() => _username = 'Guest');
    }
  }

  void _initializeYoutubePlayer(String videoId, {bool autoPlay = true}) {
    // Dispose existing controller if any
    _ytController?.dispose();

    _ytController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: autoPlay,
        mute: false,
        enableCaption: false,
        forceHD: true,
        startAt: 0,
        controlsVisibleAtStart: true,
        useHybridComposition: true,
      ),
    )..addListener(_youtubeListener);

    _currentVideoId = videoId;
  }

  void _youtubeListener() {
    if (_ytController != null && _ytController!.value.hasError) {
      print('Youtube controller encountered an error');
    }
    // Trigger UI rebuild to update progress bar
    if (mounted) setState(() {});
  }

  void _initRealtime() {
    final realtime = AppwriteService().realtime;
    // Subscribe to channels: Messages, Queue, Playback (using specific documents/collections)
    // Note: Since we flattened structure, we subscribe to filtered events if possible or just collections
    // For simplicity with flattened structure, we'll listen to the collections
    // But ideally we want channel per document for playback.

    // Channel strategy:
    // 1. Playback: databases.ID.collections.chatrooms.documents.SESSIONID (assuming playback info is on chatroom doc)
    //    OR databases.ID.collections.playback.documents.SESSIONID
    // 2. Queue: databases.ID.collections.queue.documents
    // 3. Messages: databases.ID.collections.messages.documents

    _realtimeSubscription = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.chatrooms.documents.${widget.sessionId}',
      'databases.${AppwriteConfig.databaseId}.collections.queue.documents',
      'databases.${AppwriteConfig.databaseId}.collections.messages.documents',
      'databases.${AppwriteConfig.databaseId}.collections.joinRequests.documents',
    ]);

    _realtimeSubscription!.stream.listen((event) {
      final payload = event.payload;

      // Filter events for this session
      if (payload['sessionId'] != widget.sessionId &&
          event.channels.first.contains('chatrooms') == false) {
        // If it's a queue/message event but for another session, ignore
        return;
      }

      if (event.channels.any((c) => c.contains('messages'))) {
        _handleMessageEvent(event);
      } else if (event.channels.any((c) => c.contains('queue'))) {
        _handleQueueEvent(event);
      } else if (event.channels.any((c) => c.contains('chatrooms'))) {
        _handlePlaybackUpdate(payload);
      } else if (event.channels.any((c) => c.contains('joinRequests'))) {
        _handleJoinRequestEvent(event);
      }
    });
  }

  void _handleJoinRequestEvent(RealtimeMessage event) {
    final payload = event.payload;
    if (event.events.any((e) => e.endsWith('.create'))) {
      if (payload['sessionId'] == widget.sessionId &&
          payload['status'] == 'pending') {
        setState(() => _joinRequests.add(payload));
      }
    } else if (event.events.any((e) => e.endsWith('.update'))) {
      // Update status or remove if approved/denied
      setState(() {
        final index =
            _joinRequests.indexWhere((r) => r['\$id'] == payload['\$id']);
        if (index != -1) {
          if (payload['status'] != 'pending') {
            _joinRequests.removeAt(index);
          } else {
            _joinRequests[index] = payload;
          }
        }
      });
    } else if (event.events.any((e) => e.endsWith('.delete'))) {
      setState(() {
        _joinRequests.removeWhere((item) => item['\$id'] == payload['\$id']);
      });
    }
  }

  void _handleMessageEvent(RealtimeMessage event) {
    final payload = event.payload;
    if (event.events.any((e) => e.endsWith('.create'))) {
      setState(() {
        _messages.add(payload);
        // Auto scroll
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
              _scrollController.position.maxScrollExtent + 100,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    }
    // Handle delete/update if needed
  }

  void _handleQueueEvent(RealtimeMessage event) {
    // Refresh queue or update local list
    // Simplest is to refetch queue or append if create
    final payload = event.payload;
    if (event.events.any((e) => e.endsWith('.create'))) {
      if (payload['sessionId'] == widget.sessionId) {
        setState(() => _queue.add(payload));
      }
    } else if (event.events.any((e) => e.endsWith('.delete'))) {
      setState(() {
        _queue.removeWhere((item) => item['\$id'] == payload['\$id']);
      });
    }
  }

  void _handlePlaybackUpdate(Map<String, dynamic> payload) {
    if (payload['currentSong'] != null) {
      final songData = payload['currentSong'];
      // Ensure it's a map
      if (songData is Map) {
        _updatePlayerState(Map<String, dynamic>.from(songData));
      } else {
        // Handle case where it might be parsed differently or null
        // If it's a JSON string, decode it? Appwrite sends JSON objects usually.
      }
    } else {
      // Song removed or null
      _ytController?.pause();
      // Optionally dispose if you want
    }
  }

  Future<void> _playFirstSongInQueue() async {
    if (_isLoadingNext) return;
    setState(() => _isLoadingNext = true);

    try {
      final queueDocs = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'queue',
        queries: [
          Query.equal('sessionId', widget.sessionId),
          Query.orderAsc('timestamp'),
          Query.limit(1),
        ],
      );

      if (queueDocs.documents.isEmpty) {
        setState(() => _isLoadingNext = false);
        return;
      }

      final firstSong = queueDocs.documents.first;
      final songData = firstSong.data;
      final videoId = songData['ytId'] as String?;

      if (videoId == null || videoId.isEmpty) {
        setState(() => _isLoadingNext = false);
        return;
      }

      // Update Chatroom with current song
      await AppwriteService().databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'chatrooms',
        documentId: widget.sessionId,
        data: {
          'currentSong': {
            'title': songData['title'],
            'artist': songData['artist'],
            'image': songData['image'],
            'ytId': videoId,
            'position': 0,
            'isPlaying': true,
            'timestamp': DateTime.now().toIso8601String(),
          }
        },
      );

      // Remove from queue
      await AppwriteService().databases.deleteDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'queue',
            documentId: firstSong.$id,
          );
    } catch (e) {
      print('Error playing first song: $e');
    } finally {
      if (mounted) setState(() => _isLoadingNext = false);
    }
  }

  void _updatePlayerState(Map<String, dynamic> data) {
    final videoId = data['ytId'] as String?;
    if (videoId == null || videoId.isEmpty) return;

    // If same video, don't reload
    if (videoId == _currentVideoId && _ytController != null) return;

    // Initialize or reload the player with the new video
    _initializeYoutubePlayer(videoId, autoPlay: data['isPlaying'] ?? true);
    setState(() {});
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
    setState(() => _isLoadingNext = true);

    try {
      final queueDocs = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'queue',
        queries: [
          Query.equal('sessionId', widget.sessionId),
          Query.orderAsc('timestamp'),
          Query.limit(1),
        ],
      );

      if (queueDocs.documents.isEmpty) {
        // No more songs - delete current song data from chatroom
        await AppwriteService().databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'chatrooms',
          documentId: widget.sessionId,
          data: {'currentSong': null}, // Or clear it
        );
        return;
      }

      final nextSong = queueDocs.documents.first;
      final songData = nextSong.data;
      final videoId = songData['ytId'] as String?;

      if (videoId == null || videoId.isEmpty) return;

      // Update Chatroom with current song
      await AppwriteService().databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'chatrooms',
        documentId: widget.sessionId,
        data: {
          'currentSong': {
            'title': songData['title'],
            'artist': songData['artist'],
            'image': songData['image'],
            'ytId': videoId,
            'position': 0,
            'isPlaying': true,
            'timestamp': DateTime.now().toIso8601String(),
          }
        },
      );

      // Remove from queue
      await AppwriteService().databases.deleteDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'queue',
            documentId: nextSong.$id,
          );
    } catch (e) {
      print('Error playing next song: $e');
    } finally {
      if (mounted) setState(() => _isLoadingNext = false);
    }
  }

  Widget _buildQueueList() {
    if (_queue.isEmpty) {
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
        itemCount: _queue.length,
        itemBuilder: (context, index) {
          final song = _queue[index];
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
                      song['image'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child:
                              Icon(Icons.music_note, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  song['title'] ?? 'Unknown',
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
  }

  Widget _buildMiniPlayer() {
    final metadata = _ytController?.metadata;
    final position = _ytController?.value.position ?? Duration.zero;
    final duration = metadata?.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      height: 85,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: GlassContainer(
        height: 85,
        borderRadius: BorderRadius.circular(20),
        color: AuraColors.deepBlack,
        opacity: 0.6,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Thumbnail
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _ytController != null
                            ? Image.network(
                                'https://img.youtube.com/vi/${_ytController!.metadata.videoId}/default.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AuraColors.electricViolet
                                      .withOpacity(0.2),
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white54),
                                ),
                              )
                            : Container(
                                color:
                                    AuraColors.electricViolet.withOpacity(0.2),
                                child: const Icon(Icons.music_note,
                                    color: Colors.white54),
                              ),
                      ),
                    ),
                  ),

                  // Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metadata?.title ?? 'Jam Session',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metadata?.author ?? 'Queued songs will appear here',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  IconButton(
                    icon: Icon(
                      _ytController?.value.isPlaying ?? false
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: AuraColors.electricViolet,
                      size: 40,
                    ),
                    onPressed: () {
                      if (_ytController?.value.isPlaying ?? false) {
                        _ytController?.pause();
                      } else {
                        _ytController?.play();
                      }
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded,
                        color: Colors.white70),
                    onPressed: () => setState(() => _isVideoExpanded = true),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Progress Bar
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AuraColors.electricViolet.withOpacity(0.8),
                ),
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  Widget _buildCompactVideoPlayer() {
    // Use a Stack to keep the YoutubePlayer always mounted
    // This prevents the player from stopping when switching between expanded/mini views
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Always keep the YoutubePlayer mounted but hidden when collapsed
        Offstage(
          offstage: !_isVideoExpanded,
          child: _buildExpandedPlayer(),
        ),
        // Show mini player when collapsed
        if (!_isVideoExpanded) _buildMiniPlayer(),
      ],
    );
  }

  Widget _buildExpandedPlayer() {
    return Container(
      decoration: const BoxDecoration(
        color: AuraColors.deepBlack,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Video Player - always mounted
            Container(
              height: 200,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AuraColors.electricViolet.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _ytController != null
                    ? YoutubePlayer(
                        controller: _ytController!,
                        showVideoProgressIndicator: true,
                        progressIndicatorColor: AuraColors.electricViolet,
                        progressColors: const ProgressBarColors(
                          playedColor: AuraColors.electricViolet,
                          handleColor: Colors.white,
                        ),
                      )
                    : Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(Icons.music_note,
                              color: Colors.white24, size: 64),
                        ),
                      ),
              ),
            ),

            // Controls & Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    _ytController?.metadata.title ?? 'No song playing',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ytController?.metadata.author ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(
                            _ytController?.value.position ?? Duration.zero),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      Text(
                        _formatDuration(
                            _ytController?.metadata.duration ?? Duration.zero),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () {
                          final current =
                              _ytController?.value.position ?? Duration.zero;
                          _ytController
                              ?.seekTo(current - const Duration(seconds: 10));
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AuraColors.electricViolet,
                          boxShadow: [
                            BoxShadow(
                              color: AuraColors.electricViolet.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _ytController?.value.isPlaying ?? false
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                          onPressed: () {
                            if (_ytController?.value.isPlaying ?? false) {
                              _ytController?.pause();
                            } else {
                              _ytController?.play();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded,
                            color: Colors.white, size: 32),
                        onPressed: _playNextSong,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Queue",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            _buildQueueList(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: TextButton.icon(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    label: const Text('Collapse'),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.white60),
                    onPressed: () => setState(() => _isVideoExpanded = false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return GlassContainer(
      color: AuraColors.deepBlack,
      opacity: 0.9,
      blur: 20,
      borderRadius: BorderRadius.zero,
      child: SafeArea(
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
                        backgroundImage:
                            NetworkImage(result['thumbnail'] ?? ''),
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
      await AppwriteService().databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'queue',
        documentId: ID.unique(),
        data: {
          'sessionId': widget.sessionId,
          'title': song['title'],
          'artist': song['artist'],
          'image': song['thumbnail'],
          'ytId': song['ytId'],
          'addedBy': _userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to queue: ${song['title']}')),
      );
    } catch (e) {
      print('Error adding to queue: $e');
    }
  }

  Widget _buildChatSection() {
    return Container(
      decoration: const BoxDecoration(
        color: AuraColors.deepBlack, // Premium dark background
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                // _messages contains maps from Appwrite
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black38,
              border:
                  Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: SafeArea(
              // Safe area for iPhone X+
              child: Row(
                children: [
                  Expanded(
                    child: GlassContainer(
                      height: 50,
                      borderRadius: BorderRadius.circular(25),
                      color: Colors.white,
                      opacity: 0.05,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _inputNode,
                              style: const TextStyle(color: Colors.white),
                              cursorColor: AuraColors.electricViolet,
                              decoration: InputDecoration(
                                hintText: 'Type a vibe check...',
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.4)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded),
                            color: AuraColors.electricViolet,
                            onPressed: _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isCurrentUser = message['userId'] == _userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AuraColors.electricViolet.withOpacity(0.2),
              child: Text(
                (message['username'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: AuraColors.electricViolet,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isCurrentUser
                    ? const LinearGradient(
                        colors: [AuraColors.electricViolet, Color(0xFF9D4EDD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isCurrentUser ? null : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isCurrentUser ? const Radius.circular(4) : null,
                  bottomLeft: !isCurrentUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser) ...[
                    Text(
                      message['username'] ?? 'Anonymous',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message['text'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(message['timestamp']),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
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
      final text = _messageController.text.trim();
      _messageController.clear(); // Clear immediately

      await AppwriteService().databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'messages',
        documentId: ID.unique(),
        data: {
          'sessionId': widget.sessionId,
          'text': text,
          'userId': _userId,
          'username': _username ?? 'Anonymous',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // No need to manually scroll here, the realtime listener handles it
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
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (confirmClose == true) {
        // With Appwrite, assuming we implement a cloud function to cascade delete
        // Or we just delete the chatroom doc.
        // For now, let's just delete the chatroom doc.
        // Real cascading deletion should be done on backend or by listing and deleting.

        await AppwriteService().databases.deleteDocument(
              databaseId: AppwriteConfig.databaseId,
              collectionId: 'chatrooms',
              documentId: widget.sessionId,
            );

        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error closing chatroom: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to close chatroom: $e')),
      );
    }
  }

  Widget _buildJoinRequestsList() {
    if (_joinRequests.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(8.0),
      child: GlassContainer(
        color: AuraColors.electricViolet,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _joinRequests.length,
              itemBuilder: (context, index) {
                final request = _joinRequests[index];

                return ListTile(
                  title: Text(
                    request['username'] ?? 'Unknown User',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approveJoinRequest(widget.sessionId,
                            request['\$id'], request['userId']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            _denyJoinRequest(widget.sessionId, request['\$id']),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveJoinRequest(
      String sessionId, String requestId, String userId) async {
    try {
      await AppwriteService().databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'joinRequests',
        documentId: requestId,
        data: {'status': 'approved'},
      );

      // Add user to approved users list in Chatroom
      final chatroom = await AppwriteService().databases.getDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'chatrooms',
            documentId: sessionId,
          );

      List<dynamic> approvedUsers = chatroom.data['approvedUsers'] ?? [];
      if (!approvedUsers.contains(userId)) {
        approvedUsers.add(userId);
        await AppwriteService().databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'chatrooms',
          documentId: sessionId,
          data: {'approvedUsers': approvedUsers},
        );
      }
      setState(() {});
    } catch (e) {
      print('Error approving request: $e');
    }
  }

  Future<void> _denyJoinRequest(String sessionId, String requestId) async {
    try {
      await AppwriteService().databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'joinRequests',
        documentId: requestId,
        data: {'status': 'denied'},
      );
      setState(() {});
    } catch (e) {
      print('Error denying request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.deepBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Jam Session',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: GlassContainer(
          height: kToolbarHeight + MediaQuery.of(context).padding.top,
          color: AuraColors.deepBlack,
          opacity: 0.5,
          borderRadius: BorderRadius.zero,
          child: const SizedBox.shrink(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () => setState(() => _isSearching = true),
          ),
          if (widget.isHost)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: _closeChatroom,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Main Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E), // Deep Blue/Black
                  AuraColors.deepBlack,
                ],
              ),
            ),
          ),

          Column(
            children: [
              SizedBox(
                  height:
                      kToolbarHeight + MediaQuery.of(context).padding.top + 10),

              // Video Player Section
              _buildCompactVideoPlayer(),

              // Join Requests (Host)
              if (widget.isHost) _buildJoinRequestsList(),

              // Chat
              Expanded(child: _buildChatSection()),
            ],
          ),

          // Search Overlay
          if (_isSearching) Positioned.fill(child: _buildSearchOverlay()),
        ],
      ),
    );
  }
}
