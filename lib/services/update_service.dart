import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

Future<bool> checkForUpdate() async {
  try {
    final response = await http.get(Uri.parse(
        'https://appho.st/api/get_current_version/?u=sMtdew7EjLQB8DDrUlIl2mFVL2o2&a=7Rtaihlis6lr5iyZd0os&platform=android'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final latestVersion = data['latestVersion']; // Example field
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      return currentVersion != latestVersion;
    } else {
      return false;
    }
  } catch (e) {
    print('Error checking for update: $e');
    return false;
  }
}
