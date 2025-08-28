import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatroom_page.dart';

class JoinChatroomPage extends StatefulWidget {
  @override
  _JoinChatroomPageState createState() => _JoinChatroomPageState();
}

class _JoinChatroomPageState extends State<JoinChatroomPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  final TextEditingController _chatroomNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatroomNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chatrooms'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Create Chatroom'),
            Tab(text: 'Join Chatroom'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateChatroomTab(context),
          _buildJoinChatroomTab(context),
        ],
      ),
    );
  }

  Widget _buildCreateChatroomTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _chatroomNameController,
            decoration: InputDecoration(
              labelText: 'Chatroom Name',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final chatroomName = _chatroomNameController.text;
              if (chatroomName.isNotEmpty) {
                final chatroomId =
                    await _createChatroomInFirestore(chatroomName);
                _chatroomNameController.clear();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatroomPage(
                      sessionId: chatroomId,
                      isHost: true,
                    ),
                  ),
                );
              }
            },
            child: Text('Create Chatroom'),
          ),
        ],
      ),
    );
  }

  Future<String> _createChatroomInFirestore(String chatroomName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return '';

    final chatroomDoc = await _firestore.collection('chatrooms').add({
      'name': chatroomName,
      'host': currentUser.uid,
      'status': 'active',
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Chatroom created')));
    return chatroomDoc.id;
  }

  Widget _buildJoinChatroomTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chatrooms')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No active chatrooms'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chatroom = snapshot.data!.docs[index];
            return FutureBuilder<DocumentSnapshot>(
              future:
                  _firestore.collection('users').doc(chatroom['host']).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return ListTile(
                    title: Text(chatroom['name']),
                    subtitle: Text('Loading host...'),
                    trailing: const ElevatedButton(
                      onPressed: null,
                      child: Text('Join'),
                    ),
                  );
                }

                if (!userSnapshot.hasData) {
                  return ListTile(
                    title: Text(chatroom['name']),
                    subtitle: Text('Host: Unknown'),
                    trailing: const ElevatedButton(
                      onPressed: null,
                      child: Text('Join'),
                    ),
                  );
                }

                final hostUsername =
                    userSnapshot.data?.get('username') ?? 'Unknown';
                final hostProfileImageUrl =
                    userSnapshot.data?.get('profileImage') ?? '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: hostProfileImageUrl.isNotEmpty
                        ? NetworkImage(hostProfileImageUrl)
                        : AssetImage('assets/default_profile.png')
                            as ImageProvider,
                  ),
                  title: Text(chatroom['name']),
                  subtitle: Text('Host: $hostUsername'),
                  trailing: ElevatedButton(
                    onPressed: () => _handleJoinChatroom(
                        context, chatroom.id, chatroom['host']),
                    child: Text('Join'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _handleJoinChatroom(
      BuildContext context, String chatroomId, String hostId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (currentUser.uid == hostId) {
      // If the current user is the host, navigate directly to the chatroom
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatroomPage(
            sessionId: chatroomId,
            isHost: true,
          ),
        ),
      );
    } else {
      // Otherwise, send an invite to the host
      await _sendInvite(context, chatroomId, hostId);
    }
  }

  Future<void> _sendInvite(
      BuildContext context, String chatroomId, String hostId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('chatroom_invites').add({
      'chatroomId': chatroomId,
      'hostId': hostId,
      'userId': currentUser.uid,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Invite sent to host')));
  }
}