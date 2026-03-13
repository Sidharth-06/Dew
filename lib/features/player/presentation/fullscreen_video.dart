import 'package:dew/features/player/logic/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPage extends ConsumerStatefulWidget {
  const FullscreenVideoPage({super.key});

  @override
  ConsumerState<FullscreenVideoPage> createState() =>
      _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends ConsumerState<FullscreenVideoPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isDocked =
      false; // toggles between immersive fullscreen and docked card

  static const _toggleDuration = Duration(milliseconds: 650);
  static const _toggleCurve = Curves.easeInOutBack;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // prepare controller from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(playerProvider).videoController;
      setState(() => _controller = controller);
    });
  }

  @override
  void dispose() {
    // restore system UI and volumes on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.read(playerProvider.notifier).exitFullscreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Animated video container — shrinks into a landscape card when docked
              Align(
                alignment: Alignment.topCenter,
                child: Hero(
                  tag: 'video_player_card', // Matches PlayerPage tag
                  child: AnimatedPadding(
                    duration: _toggleDuration,
                    curve: _toggleCurve,
                    padding: _isDocked
                        // Target padding to match roughly where the PlayerPage artwork sits
                        // Artwork size is 0.85 * width. Top padding is ~110px.
                        ? EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 90,
                            left: (MediaQuery.of(context).size.width * 0.075),
                            right: (MediaQuery.of(context).size.width * 0.075),
                          )
                        : EdgeInsets.zero,
                    child: AnimatedContainer(
                      duration: _toggleDuration,
                      curve: _toggleCurve,
                      width: _isDocked
                          ? MediaQuery.of(context).size.width * 0.85
                          : MediaQuery.of(context).size.width,
                      height: _isDocked
                          ? MediaQuery.of(context).size.width *
                              0.85 // Square to match artwork size
                          : MediaQuery.of(context).size.height,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(
                            _isDocked ? 28.0 : 0.0), // Match artwork radius 28
                        boxShadow: _isDocked
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(_isDocked ? 28.0 : 0.0),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top-left close
              if (_showControls)
                Positioned(
                  top: 16,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

              // Top-right dock/undock toggle
              if (_showControls)
                Positioned(
                  top: 16,
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                      _isDocked ? Icons.fullscreen : Icons.fullscreen_exit,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      setState(() => _isDocked = !_isDocked);
                      if (_isDocked) {
                        SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.edgeToEdge);
                        // Wait for animation, then pop back to PlayerPage
                        await Future.delayed(_toggleDuration);
                        if (mounted) Navigator.pop(context);
                      } else {
                        SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.immersiveSticky);
                        await ref
                            .read(playerProvider.notifier)
                            .prepareFullscreen();
                      }
                    },
                  ),
                ),

              // Bottom controls
              if (_showControls)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white),
                          onPressed: () {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon:
                              const Icon(Icons.volume_up, color: Colors.white),
                          onPressed: () async {
                            final vol =
                                _controller!.value.volume > 0 ? 0.0 : 1.0;
                            await _controller!.setVolume(vol);
                            // if unmuted, ensure fullscreen prepare to mute audio handler
                            if (vol > 0) {
                              await ref
                                  .read(playerProvider.notifier)
                                  .prepareFullscreen();
                            } else {
                              await ref
                                  .read(playerProvider.notifier)
                                  .exitFullscreen();
                            }
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
