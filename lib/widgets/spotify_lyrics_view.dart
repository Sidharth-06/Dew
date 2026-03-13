import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dew/main.dart';
import 'package:dew/models/position_data.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/features/player/logic/lyrics_helper.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// Spotify-style scrollable lyrics widget with auto-scroll to current line
class SpotifyLyricsView extends StatefulWidget {
  final MediaItem metadata;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  const SpotifyLyricsView({
    super.key,
    required this.metadata,
    this.isFullscreen = false,
    this.onToggleFullscreen,
  });

  @override
  State<SpotifyLyricsView> createState() => _SpotifyLyricsViewState();
}

class _SpotifyLyricsViewState extends State<SpotifyLyricsView>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  int _currentLineIndex = -1;
  bool _isUserScrolling = false;
  Timer? _userScrollTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant SpotifyLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.id != widget.metadata.id) {
      _loadLyrics();
    }
  }

  Future<void> _loadLyrics() async {
    final plainLyrics = await getSongLyrics(
      widget.metadata.artist ?? '',
      widget.metadata.title,
    );

    if (plainLyrics == null ||
        plainLyrics.trim().isEmpty ||
        plainLyrics.toLowerCase().contains('not found') ||
        plainLyrics.toLowerCase().contains('error') ||
        plainLyrics.toLowerCase().contains('no lyrics') ||
        plainLyrics.length < 10) {
      setState(() {
        _lyrics = [];
      });
      return;
    }

    // Process lyrics using smart sync algorithm
    final duration = widget.metadata.duration ?? Duration.zero;
    final lines = LyricsHelper.getSyncedLyrics(plainLyrics, duration);

    setState(() {
      _lyrics = lines;
    });
    _fadeController.forward();
  }

  void _scrollToCurrentLine(int lineIndex) {
    if (_isUserScrolling || !_scrollController.hasClients || lineIndex < 0) {
      return;
    }

    // Calculate scroll position to center the current line
    final itemHeight = 60.0; // Approximate height per lyric line
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetScroll =
        (lineIndex * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
    final clampedScroll = targetScroll.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedScroll,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUserScroll() {
    _isUserScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 3), () {
      _isUserScrolling = false;
      // Resume auto-scroll after user stops scrolling
      if (_currentLineIndex >= 0) {
        _scrollToCurrentLine(_currentLineIndex);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _userScrollTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVideo = widget.metadata.extras?['isVideo'] ?? false;

    if (isVideo) return const SizedBox.shrink();

    if (_lyrics.isEmpty) {
      return _buildLoadingOrEmpty(theme);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              theme.colorScheme.surface.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              _buildHeader(theme),
              SizedBox(
                height: widget.isFullscreen
                    ? MediaQuery.of(context).size.height * 0.6
                    : 350,
                child: _buildLyricsScroller(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FluentIcons.music_note_2_24_filled,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Lyrics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          if (widget.onToggleFullscreen != null)
            IconButton(
              onPressed: widget.onToggleFullscreen,
              icon: Icon(
                widget.isFullscreen
                    ? FluentIcons.arrow_minimize_24_regular
                    : FluentIcons.arrow_maximize_24_regular,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: widget.isFullscreen ? 'Minimize' : 'Fullscreen',
            ),
        ],
      ),
    );
  }

  Widget _buildLyricsScroller(ThemeData theme) {
    return StreamBuilder<PositionData>(
      stream: audioHandler.positionDataStream,
      builder: (context, snapshot) {
        final positionMs = snapshot.data?.position.inMilliseconds ?? 0;

        // Find current line based on position
        int newCurrentLine = -1;
        for (int i = 0; i < _lyrics.length; i++) {
          final startMs = _lyrics[i].startTime.inMilliseconds;
          final endMs = _lyrics[i].endTime.inMilliseconds;

          if (positionMs >= startMs && positionMs < endMs) {
            newCurrentLine = i;
            break;
          }
          // If we're past the start but before the next line
          if (positionMs >= startMs &&
              (i == _lyrics.length - 1 ||
                  positionMs < _lyrics[i + 1].startTime.inMilliseconds)) {
            newCurrentLine = i;
          }
        }

        // Update current line and scroll if changed
        if (newCurrentLine != _currentLineIndex && newCurrentLine >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentLineIndex = newCurrentLine;
              });
              _scrollToCurrentLine(newCurrentLine);
            }
          });
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _onUserScroll();
            }
            return false;
          },
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.08, 0.92, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              itemCount: _lyrics.length,
              itemBuilder: (context, index) {
                return _buildLyricLine(index, theme);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricLine(int index, ThemeData theme) {
    final lyric = _lyrics[index];
    final isCurrent = index == _currentLineIndex;
    final isPast = index < _currentLineIndex;

    return GestureDetector(
      onTap: () {
        // Seek to this lyric line when tapped
        audioHandler.seek(lyric.startTime);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: isCurrent ? 16 : 10,
          horizontal: 8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCurrent
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          // Use different text style/color for chorus?
          // border: lyric.isChorus ? Border(left: BorderSide(color: theme.colorScheme.secondary, width: 2)) : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: isCurrent ? 22 : 17,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent
                ? theme.colorScheme.primary
                : isPast
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.4,
            letterSpacing: isCurrent ? -0.3 : 0,
          ),
          textAlign: TextAlign.center,
          child: Text(
            lyric.text,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrEmpty(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.music_note_2_24_regular,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No lyrics available',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lyrics for this song could not be found',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
