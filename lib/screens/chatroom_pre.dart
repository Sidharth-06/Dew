import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dew/screens/chatroom_page.dart';
import 'package:dew/screens/register_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatroomPrePage extends StatefulWidget {
  const ChatroomPrePage({super.key});

  @override
  _ChatroomPrePageState createState() => _ChatroomPrePageState();
}

class _ChatroomPrePageState extends State<ChatroomPrePage> {
  final TextEditingController _chatroomNameController = TextEditingController();
  final FocusNode _chatroomNameFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isCreating = true;
  bool _isLoading = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
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

  Future<bool> _checkAuthentication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return true;

    bool shouldNavigate = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Authentication Required'),
              content: const Text(
                  'You need to register or login to create or join chatrooms.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldNavigate) {
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RegisterPage()),
      ));
    }
    return false;
  }

  Future<void> _createChatroom() async {
    final isAuth = await _checkAuthentication();
    if (!isAuth) return;

    setState(() {
      _isLoading = true;
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final chatroomDoc = await _firestore.collection('chatrooms').add({
        'hostId': currentUser.uid,
        'hostName': _username,
        'chatroomName': _chatroomNameController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'approvedUsers': [currentUser.uid], // Initialize with host
      });

      unawaited(Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatroomPage(
            sessionId: chatroomDoc.id,
            isHost: true,
          ),
        ),
      ));
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _sendJoinRequest(String chatroomId) async {
    final isAuth = await _checkAuthentication();
    if (!isAuth) return;

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Check if user already has a pending request
      final existingRequests = await _firestore
          .collection('chatrooms')
          .doc(chatroomId)
          .collection('joinRequests')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have a pending request')),
        );
        return;
      }

      // Check if user is already approved
      final chatroomDoc =
          await _firestore.collection('chatrooms').doc(chatroomId).get();
      final approvedUsers =
          List<String>.from(chatroomDoc.data()?['approvedUsers'] ?? []);

      if (approvedUsers.contains(currentUser.uid)) {
        // User is already approved, navigate to chatroom
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatroomPage(
              sessionId: chatroomId,
              isHost: false,
            ),
          ),
        );
        return;
      }

      // Send join request
      await _firestore
          .collection('chatrooms')
          .doc(chatroomId)
          .collection('joinRequests')
          .add({
        'userId': currentUser.uid,
        'username': _username,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Join request sent. Waiting for host approval.')),
      );
    }
  }

  Widget _buildChatroomCreation() {
    return Column(
      children: [
        TextField(
          controller: _chatroomNameController,
          focusNode: _chatroomNameFocusNode,
          decoration: InputDecoration(
            labelText: _chatroomNameFocusNode.hasFocus ? null : 'Chatroom Name',
            labelStyle: const TextStyle(color: Colors.black),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[200],
          ),
          style: const TextStyle(color: Colors.black), // Ensure text is visible
          onTap: () {
            setState(() {});
          },
          onEditingComplete: () {
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _createChatroom,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Create Chatroom', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildChatroomJoin() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('chatrooms').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chatrooms = snapshot.data!.docs;
        return ListView.builder(
          itemCount: chatrooms.length,
          itemBuilder: (context, index) {
            final chatroom = chatrooms[index];
            final chatroomData = chatroom.data() as Map<String, dynamic>;
            final approvedUsers =
                List<String>.from(chatroomData['approvedUsers'] ?? []);
            final currentUserId = _auth.currentUser?.uid;

            if (chatroomData.containsKey('chatroomName') &&
                chatroomData.containsKey('hostName')) {
              final chatroomName = chatroomData['chatroomName'];
              final hostName = chatroomData['hostName'];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(chatroomName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Host: $hostName'),
                  trailing: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chatrooms')
                        .doc(chatroom.id)
                        .collection('joinRequests')
                        .where('userId', isEqualTo: currentUserId)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, requestSnapshot) {
                      final hasPendingRequest = requestSnapshot.hasData &&
                          requestSnapshot.data!.docs.isNotEmpty;

                      if (chatroomData['hostId'] == currentUserId) {
                        return IconButton(
                          icon: const Icon(Icons.home, color: Colors.green),
                          onPressed: () => _enterChatroom(chatroom.id, true),
                        );
                      } else if (approvedUsers.contains(currentUserId)) {
                        return IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green),
                          onPressed: () => _enterChatroom(chatroom.id, false),
                        );
                      } else if (hasPendingRequest) {
                        return const Icon(Icons.hourglass_empty,
                            color: Colors.orange);
                      } else {
                        return IconButton(
                          icon: const Icon(Icons.group_add, color: Colors.blue),
                          onPressed: () => _sendJoinRequest(chatroom.id),
                        );
                      }
                    },
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  void _enterChatroom(String chatroomId, bool isHost) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatroomPage(
          sessionId: chatroomId,
          isHost: isHost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatroom'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ToggleButtons(
              borderRadius: BorderRadius.circular(24),
              isSelected: [_isCreating, !_isCreating],
              onPressed: (index) {
                setState(() {
                  _isCreating = index == 0;
                });
              },
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child:
                      Text('Create Chatroom', style: TextStyle(fontSize: 16)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Join Chatroom', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isCreating ? _buildChatroomCreation() : _buildChatroomJoin(),
          ),
        ],
      ),
    );
  }
}
