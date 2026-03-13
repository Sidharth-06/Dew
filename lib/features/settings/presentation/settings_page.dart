import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:dew/API/musify.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.deepBlack,
      appBar: AppBar(
        backgroundColor: AuraColors.deepBlack,
        title: Text(
          'Dew Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _sectionLabel('Playback'),
          _buildSwitchTile(
            title: 'Auto play next song',
            subtitle: 'Keep the music flowing after each track.',
            icon: Icons.queue_music_rounded,
            listenable: playNextSongAutomatically,
            onChanged: (val) {
              playNextSongAutomatically.value = val;
              Hive.box('settings').put('playNextSongAutomatically', val);
            },
          ),
          _buildSwitchTile(
            title: 'Offline mode',
            subtitle: 'Use downloaded songs only and reduce data usage.',
            icon: Icons.cloud_off_rounded,
            listenable: offlineMode,
            onChanged: (val) {
              offlineMode.value = val;
              Hive.box('settings').put('offlineMode', val);
            },
          ),
          _buildAudioQualityTile(context),
          _buildPlayerStyleTile(context),
          _sectionLabel('Video'),
          _buildVideoLiteTile(),
          _sectionLabel('App'),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white),
            title:
                const Text('About Dew', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Open source, community-driven audio.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Dew',
                applicationVersion:
                    Hive.box('settings').get('appVersion', defaultValue: ''),
                applicationIcon: const Icon(Icons.blur_on_rounded),
                children: const [
                  Text('Built with love for music discovery.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueListenable<bool> listenable,
    required ValueChanged<bool> onChanged,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, value, _) {
        return SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AuraColors.electricViolet,
          inactiveThumbColor: Colors.white70,
          inactiveTrackColor: Colors.white24,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          secondary: Icon(icon, color: Colors.white),
        );
      },
    );
  }

  Widget _buildPlayerStyleTile(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: playerStyleSetting,
      builder: (context, style, _) {
        return ExpansionTile(
          leading: const Icon(Icons.play_circle_fill, color: Colors.white),
          title:
              const Text('Player Style', style: TextStyle(color: Colors.white)),
          collapsedIconColor: Colors.white,
          iconColor: Colors.white,
          children: [
            RadioListTile<String>(
              value: 'default',
              groupValue: style,
              activeColor: AuraColors.electricViolet,
              title: const Text('Default player',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Classic artwork-based player UI',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              onChanged: (val) => _updatePlayerStyle(val),
            ),
            RadioListTile<String>(
              value: 'video',
              groupValue: style,
              activeColor: AuraColors.electricViolet,
              title: const Text('Video background player',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                  'Play the song video blurred behind the controls',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              onChanged: (val) => _updatePlayerStyle(val),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAudioQualityTile(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: audioQualitySetting,
      builder: (context, quality, _) {
        String label;
        switch (quality) {
          case 'low':
            label = 'Low (data saver)';
            break;
          case 'medium':
            label = 'Medium';
            break;
          default:
            label = 'High (default)';
        }

        return ListTile(
          leading: const Icon(Icons.equalizer, color: Colors.white),
          title: const Text('Audio quality',
              style: TextStyle(color: Colors.white)),
          subtitle: Text(label, style: const TextStyle(color: Colors.white70)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
          onTap: () => _showQualitySheet(context, quality),
        );
      },
    );
  }

  void _showQualitySheet(BuildContext context, String current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AuraColors.deepBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'high',
              groupValue: current,
              activeColor: AuraColors.electricViolet,
              title: const Text('High (default)',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Best detail; uses more data.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              onChanged: (val) => _updateQuality(context, val),
            ),
            RadioListTile<String>(
              value: 'medium',
              groupValue: current,
              activeColor: AuraColors.electricViolet,
              title:
                  const Text('Medium', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Balanced quality and data.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              onChanged: (val) => _updateQuality(context, val),
            ),
            RadioListTile<String>(
              value: 'low',
              groupValue: current,
              activeColor: AuraColors.electricViolet,
              title: const Text('Low (data saver)',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Smallest data use; fastest loads.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              onChanged: (val) => _updateQuality(context, val),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  void _updateQuality(BuildContext context, String? value) {
    if (value == null) return;
    audioQualitySetting.value = value;
    Hive.box('settings').put('audioQuality', value);
    Navigator.of(context).pop();
  }

  void _updatePlayerStyle(String? style) {
    if (style == null) return;
    debugPrint('🎬 Settings: updating playerStyle to $style');
    playerStyleSetting.value = style;
    Hive.box('settings').put('playerStyle', style);
    debugPrint('🎬 Settings: playerStyle now = ${playerStyleSetting.value}');
  }

  Widget _buildVideoLiteTile() {
    return ValueListenableBuilder<bool>(
      valueListenable: videoLiteMode,
      builder: (context, enabled, _) {
        return SwitchListTile.adaptive(
          value: enabled,
          onChanged: (val) => setVideoLiteMode(val),
          activeColor: AuraColors.electricViolet,
          inactiveThumbColor: Colors.white70,
          inactiveTrackColor: Colors.white24,
          title: const Text('Video Lite Mode',
              style: TextStyle(color: Colors.white)),
          subtitle: const Text(
            'Cap video at 720p on limited networks; keeps audio quality and stability.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        );
      },
    );
  }
}
