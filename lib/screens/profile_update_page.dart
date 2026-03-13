import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:dew/config/appwrite_config.dart';
import 'package:dew/services/appwrite_service.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileUpdatePage extends StatefulWidget {
  const ProfileUpdatePage({Key? key}) : super(key: key);

  @override
  _ProfileUpdatePageState createState() => _ProfileUpdatePageState();
}

class _ProfileUpdatePageState extends State<ProfileUpdatePage> {
  final TextEditingController _nameController = TextEditingController();
  String? _profilePictureUrl;
  File? _profilePictureFile;
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await AppwriteService().account.get();
      final userDoc = await AppwriteService().databases.getDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'users',
            documentId: user.$id,
          );

      final userData = userDoc.data;
      _nameController.text = userData['username'] ?? '';
      _profilePictureUrl = userData['profilePictureUrl'];
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profilePictureFile = File(image.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await AppwriteService().account.get();
      String? newProfilePictureUrl = _profilePictureUrl;

      // Upload new profile picture if selected
      if (_profilePictureFile != null) {
        final file = await AppwriteService().storage.createFile(
              bucketId: AppwriteConfig.bucketId,
              fileId: ID.unique(),
              file: InputFile.fromPath(path: _profilePictureFile!.path),
            );
        newProfilePictureUrl =
            '${AppwriteConfig.endpoint}/storage/buckets/${AppwriteConfig.bucketId}/files/${file.$id}/view?project=${AppwriteConfig.projectId}';
      }

      // Update user data in Database
      await AppwriteService().databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        documentId: user.$id,
        data: {
          'username': _nameController.text,
          'profilePictureUrl': newProfilePictureUrl,
        },
      );

      // Update name in Account
      await AppwriteService().account.updateName(name: _nameController.text);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: _profilePictureFile != null
                          ? FileImage(_profilePictureFile!) as ImageProvider
                          : _profilePictureUrl != null
                              ? NetworkImage(_profilePictureUrl!)
                              : const AssetImage(
                                      'assets/default_profile.png') // Replace with your default asset
                                  as ImageProvider,
                      child: _profilePictureUrl == null &&
                              _profilePictureFile == null
                          ? const Icon(Icons.camera_alt,
                              size: 40, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _updateProfile,
                    child: const Text('Update Profile'),
                  ),
                ],
              ),
            ),
    );
  }
}
