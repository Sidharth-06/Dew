import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectedDevicesPage extends StatelessWidget {
  const ConnectedDevicesPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchConnectedDevices() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final devices = userDoc.data()?['devices'] ?? [];

    return List<Map<String, dynamic>>.from(devices);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchConnectedDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No connected devices found.'));
          }

          final devices = snapshot.data!;

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device['name'] ?? 'Unknown Device'),
                subtitle: Text('Last active: ${device['lastActive'] ?? 'Unknown'}'),
              );
            },
          );
        },
      ),
    );
  }
}