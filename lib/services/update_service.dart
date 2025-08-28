import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final BuildContext context;
  final String updateMetadataUrl;

  UpdateService({
    required this.context,
    required this.updateMetadataUrl,
  });

  void checkForUpdate() async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(updateMetadataUrl);
      final metadata = await ref.getData();
      if (metadata != null) {
        final data = json.decode(utf8.decode(metadata));
        final latestVersion = data['version'];
        final newFeatures = List<String>.from(data['features']);
        final updateUrl = data['updateUrl']; // URL to the hosted app

        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (currentVersion != latestVersion) {
          _showUpdateDialog(context, latestVersion, newFeatures, updateUrl);
        }
      }
    } catch (e) {
      print('Error checking for update: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, String latestVersion,
      List<String> newFeatures, String updateUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'A new version ($latestVersion) of the app is available. Please update to the latest version.'),
              SizedBox(height: 16),
              Text('New Features:'),
              ...newFeatures.map((feature) => Text('- $feature')).toList(),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Update Now'),
              onPressed: () async {
                if (await canLaunch(updateUrl)) {
                  await launch(updateUrl);
                } else {
                  throw 'Could not launch $updateUrl';
                }
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
