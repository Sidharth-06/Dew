import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dew/extensions/l10n.dart';
import 'package:dew/main.dart';
import 'package:dew/services/data_manager.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:dew/style/app_colors.dart';
import 'package:dew/style/app_themes.dart';
import 'package:dew/utilities/flutter_bottom_sheet.dart';
import 'package:dew/widgets/custom_bar.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _checkForUpdates(BuildContext context) async {
    const updateUrl =
        'https://appho.st/api/get_current_version/?u=jZ4knXpMzDXRYL9bJgqgoqtLDA53&a=5164FjO5rpZoeR4U6bfc&platform=android';

    try {
      final response = await http.get(Uri.parse(updateUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('version') && data.containsKey('url')) {
          final latestVersion = cleanVersion(data['version']);
          final downloadUrl = data['url'];

          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = cleanVersion(packageInfo.version);

          // Compare versions using pub_semver
          final currentSemver = Version.parse(currentVersion!);
          final latestSemver = Version.parse(latestVersion!);

          if (currentSemver == latestSemver) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('App is at the latest version.'),
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            await _showUpdateDialog(context, latestVersion, downloadUrl);
          }
        } else {
          showToast(context, 'Invalid update data received.');
        }
      } else {
        showToast(context, 'Failed to check for updates.');
      }
    } catch (e) {
      showToast(context, 'Error checking for updates: $e');
    }
  }

  String? cleanVersion(String version) {
    // Extract the semantic version part from the string
    final RegExp regex = RegExp(r'^\d+\.\d+\.\d+');
    final match = regex.firstMatch(version);
    return match != null ? match.group(0) : '';
  }

  Future<void> _showUpdateDialog(
      BuildContext context, String latestVersion, String downloadUrl) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Text(
              'Version $latestVersion is available. Do you want to update?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Decline'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () async {
                final url = Uri.parse(downloadUrl);
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                  Navigator.of(context).pop();
                } catch (e) {
                  showToast(context, 'Could not launch update URL');
                }
              },
            ),
          ],
        );
      },
    );
  }

  void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activatedColor =
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final inactivatedColor = Theme.of(context).colorScheme.secondaryContainer;

    // Enable the pure black setting permanently (but don't show it in the UI)
    usePureBlackColor.value = true;
    addOrUpdateData('settings', 'usePureBlackColor', true);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n!.settings),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            // CATEGORY: PREFERENCES
            _buildSectionTitle(
              primaryColor,
              context.l10n!.preferences,
            ),
            CustomBar(
              context.l10n!.accentColor,
              FluentIcons.color_24_filled,
              onTap: () => showCustomBottomSheet(
                context,
                GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                  ),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: availableColors.length,
                  itemBuilder: (context, index) {
                    final color = availableColors[index];
                    final isSelected = color == primaryColorSetting;

                    return GestureDetector(
                      onTap: () {
                        addOrUpdateData(
                          'settings',
                          'accentColor',
                          color.value,
                        );
                        Musify.updateAppState(
                          context,
                          newAccentColor: color,
                          useSystemColor: false,
                        );
                        showToast(
                          context,
                          context.l10n!.accentChangeMsg,
                        );
                        Navigator.pop(context);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: themeMode == ThemeMode.light
                                ? color.withAlpha(150)
                                : color,
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            CustomBar(
              context.l10n!.themeMode,
              FluentIcons.weather_sunny_28_filled,
              onTap: () {
                final availableModes = [
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ];
                showCustomBottomSheet(
                  context,
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: availableModes.length,
                    itemBuilder: (context, index) {
                      final mode = availableModes[index];
                      return Card(
                        margin: const EdgeInsets.all(10),
                        color: themeMode == mode
                            ? activatedColor
                            : inactivatedColor,
                        child: ListTile(
                          minTileHeight: 65,
                          title: Text(
                            mode.name,
                          ),
                          onTap: () {
                            addOrUpdateData(
                              'settings',
                              'themeMode',
                              mode.name,
                            );
                            Musify.updateAppState(
                              context,
                              newThemeMode: mode,
                            );
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            CustomBar(
              context.l10n!.audioQuality,
              Icons.music_note,
              onTap: () {
                final availableQualities = ['low', 'medium', 'high'];

                showCustomBottomSheet(
                  context,
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: availableQualities.length,
                    itemBuilder: (context, index) {
                      final quality = availableQualities[index];
                      final isCurrentQuality =
                          audioQualitySetting.value == quality;

                      return Card(
                        color: isCurrentQuality
                            ? activatedColor
                            : inactivatedColor,
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          minTileHeight: 65,
                          title: Text(quality),
                          onTap: () {
                            addOrUpdateData(
                              'settings',
                              'audioQuality',
                              quality,
                            );
                            audioQualitySetting.value = quality;

                            showToast(
                              context,
                              context.l10n!.audioQualityMsg,
                            );
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // Add "Check for Update" button
            CustomBar(
              context.l10n!.showQueue,
              Icons.system_update,
              onTap: () => _checkForUpdates(context),
            ),
            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(Color primaryColor, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: primaryColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
