import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:dew/config/appwrite_config.dart';
import 'package:dew/services/appwrite_service.dart';
import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/core/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class ChatroomPrePage extends StatefulWidget {
  const ChatroomPrePage({super.key});

  @override
  _ChatroomPrePageState createState() => _ChatroomPrePageState();
}

class _ChatroomPrePageState extends State<ChatroomPrePage> {
  final TextEditingController _chatroomNameController = TextEditingController();
  bool _isCreating = true;
  bool _isLoading = false;

  Future<void> _createChatroom() async {
    if (_chatroomNameController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = await AppwriteService().account.get();
      final sessionId = const Uuid().v4();

      await AppwriteService().databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'chatrooms',
        documentId: sessionId,
        data: {
          'hostId': user.$id,
          'hostName': user.name,
          'chatroomName': _chatroomNameController.text,
          'createdAt': DateTime.now().toIso8601String(),
          'approvedUsers': [user.$id],
          'sessionId': sessionId, // Redundant but useful for queries
        },
      );

      if (mounted) context.push('/chatroom/\$sessionId');
    } catch (e) {
      print('Error creating chatroom: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: \$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendJoinRequest(String chatroomId) async {
    try {
      final user = await AppwriteService().account.get();

      // Check existing
      final existing = await AppwriteService().databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'joinRequests',
          queries: [
            Query.equal('sessionId', chatroomId),
            Query.equal('userId', user.$id),
            Query.equal('status', 'pending'),
          ]);

      if (existing.documents.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Request pending')));
        }
        return;
      }

      await AppwriteService().databases.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'joinRequests',
          documentId: ID.unique(),
          data: {
            'sessionId': chatroomId,
            'userId': user.$id,
            'username': user.name,
            'status': 'pending',
            'requestedAt': DateTime.now().toIso8601String(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Request sent')));
        setState(() {}); // Refresh UI to show pending
      }
    } catch (e) {
      print('Error sending join request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.deepBlack,
      appBar: AppBar(
        title: const Text('Chatrooms'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Toggle
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCreating = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isCreating
                            ? AuraColors.electricViolet
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(21),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Create',
                        style: TextStyle(
                          color: _isCreating ? Colors.white : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCreating = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isCreating
                            ? AuraColors.electricViolet
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(21),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Join',
                        style: TextStyle(
                          color: !_isCreating ? Colors.white : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isCreating ? _buildCreateView() : _buildJoinView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          GlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            color: Colors.white.withOpacity(0.05),
            child: Column(
              children: [
                const Icon(Icons.meeting_room_rounded,
                    size: 48, color: AuraColors.electricViolet),
                const SizedBox(height: 24),
                TextField(
                  controller: _chatroomNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Room Name',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createChatroom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuraColors.electricViolet,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Start Room',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildJoinView() {
    return FutureBuilder<models.DocumentList>(
      future: AppwriteService().databases.listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'chatrooms',
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.white)));
        }

        final docs = snapshot.data?.documents ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Text('No active rooms',
                  style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data;
            final roomId = data['sessionId'] ?? docs[index].$id;
            // Need async check for current user or pass it down.
            // For now, assume we fetch user in a parent or FutureBuilder.
            // Simplified: Re-fetching user here is bad.

            return FutureBuilder<models.User>(
                future: AppwriteService().account.get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return SizedBox.shrink();
                  final currentUser = userSnapshot.data!;
                  final isHost = data['hostId'] == currentUser.$id;
                  final approvedUsers =
                      (data['approvedUsers'] as List<dynamic>?)
                              ?.map((e) => e.toString())
                              .toList() ??
                          [];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassContainer(
                      height: 80,
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.music_note_rounded,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data['chatroomName'] ?? 'Room',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  'Host: ${data['hostName']}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          _buildJoinButton(
                              roomId, isHost, approvedUsers, currentUser.$id),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (50 * index).ms).slideX();
                });
          },
        );
      },
    );
  }

  Widget _buildJoinButton(String roomId, bool isHost,
      List<String> approvedUsers, String currentUserId) {
    if (isHost) {
      return TextButton(
        onPressed: () => context.push('/chatroom/$roomId'),
        child: const Text('Enter',
            style: TextStyle(color: AuraColors.electricViolet)),
      );
    }

    final isApproved = approvedUsers.contains(currentUserId);
    if (isApproved) {
      return TextButton(
        onPressed: () => context.push('/chatroom/$roomId'),
        child: const Text('Join', style: TextStyle(color: Colors.greenAccent)),
      );
    }

    return FutureBuilder<models.DocumentList>(
      future: AppwriteService().databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'joinRequests',
          queries: [
            Query.equal('sessionId', roomId),
            Query.equal('userId', currentUserId),
            Query.equal('status', 'pending'),
          ]),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.documents.isNotEmpty) {
          return const Text('Pending',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12));
        }
        return IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
          onPressed: () => _sendJoinRequest(roomId),
        );
      },
    );
  }
}
