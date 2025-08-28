import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FriendListPage extends StatefulWidget {
  @override
  _FriendListPageState createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> friendRequests = [];
  List<Map<String, dynamic>> allUsers = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchFriendRequests();
    _fetchAllUsers();
  }

  Future<void> _fetchFriendRequests() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final requestsQuery = await _firestore
        .collection('friend_requests')
        .where('to', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    setState(() {
      friendRequests = requestsQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Include the document ID
        return data;
      }).toList();
    });
  }

  Future<void> _fetchAllUsers() async {
    final usersQuery = await _firestore.collection('users').get();
    setState(() {
      allUsers = usersQuery.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id; // Include the document ID
        return data;
      }).toList();
    });
  }

  List<Map<String, dynamic>> get filteredUsers {
    if (searchQuery.isEmpty) {
      return allUsers;
    } else {
      return allUsers.where((user) {
        return user['username'] != null &&
            user['username'].toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> _sendFriendRequest(String friendId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Fetch the current user's username
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final username = userDoc.data()?['username'] ?? 'Unknown';

    await FirebaseFirestore.instance.collection('friend_requests').add({
      'from': currentUser.uid,
      'to': friendId,
      'from_name': username, // Include the username
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request sent')),
    );

    await _fetchFriendRequests();
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'accepted',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted')),
      );
      await _fetchFriendRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting friend request: $e')),
      );
    }
  }

  Future<void> _declineFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request declined')),
      );
      await _fetchFriendRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining friend request: $e')),
      );
    }
  }

  void _copyToClipboard(String friendId) {
    Clipboard.setData(ClipboardData(text: friendId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend ID copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Users by Username',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 20),
            // Friend Requests Section
            const Text(
              'Friend Requests',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: friendRequests.isEmpty
                  ? const Center(child: Text('No friend requests'))
                  : ListView.builder(
                      itemCount: friendRequests.length,
                      itemBuilder: (context, index) {
                        final request = friendRequests[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(request['from_name'] ??
                                'No username'), // Display the username
                            subtitle: Text(
                                'Friend ID: ${request['from']}'), // Display the friend ID
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () {
                                    if (request['id'] != null) {
                                      _acceptFriendRequest(request[
                                          'id']); // Ensure request['id'] is passed
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Error: Request ID is invalid')),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () {
                                    if (request['id'] != null) {
                                      _declineFriendRequest(request[
                                          'id']); // Ensure request['id'] is passed
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Error: Request ID is invalid')),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () =>
                                      _copyToClipboard(request['from']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),
            // Users Section
            const Text(
              'Users',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredUsers.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(user['username'] ??
                                'No username'), // Display the username
                            trailing: IconButton(
                              icon: const Icon(Icons.person_add),
                              onPressed: () {
                                if (user['uid'] != null &&
                                    user['uid'].isNotEmpty) {
                                  _sendFriendRequest(user[
                                      'uid']); // Send the friend request to this user
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Error: Friend ID is invalid')),
                                  );
                                }
                              },
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
}
