import 'package:Dew/main.dart';
import 'package:Dew/screens/search_page.dart';
import 'package:Dew/style/app_themes.dart';
import 'package:Dew/widgets/custom_bar.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:Dew/API/musify.dart';
import 'package:Dew/extensions/l10n.dart';
import 'package:Dew/services/data_manager.dart';
import 'package:Dew/services/router_service.dart';
import 'package:Dew/services/settings_manager.dart';
import 'package:Dew/services/update_manager.dart';
import 'package:Dew/style/app_colors.dart';
import 'package:Dew/utilities/flutter_bottom_sheet.dart';
import 'package:Dew/utilities/flutter_toast.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
              context.l10n!.checkupdate,
              FluentIcons.arrow_download_24_filled,
              onTap: checkAppUpdates,
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
