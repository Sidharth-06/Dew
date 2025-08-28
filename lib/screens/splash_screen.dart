import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class DewMountainSplash extends StatefulWidget {
  final VoidCallback onFinish;
  final Duration maxDuration;

  const DewMountainSplash({
    Key? key,
    required this.onFinish,
    this.maxDuration = const Duration(seconds: 4),
  }) : super(key: key);

  @override
  State<DewMountainSplash> createState() => _DewMountainSplashState();
}

class _DewMountainSplashState extends State<DewMountainSplash>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _taglineOpacity;
  Timer? _timeout;

  final String _title = 'Dew';

  @override
  void initState() {
    super.initState();

    // slightly longer so animations complete visibly
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    // Tagline appears after logo animation completes
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.75, curve: Curves.easeIn),
      ),
    );

    // safety timeout fallback
    _timeout = Timer(widget.maxDuration, () {
      if (mounted) widget.onFinish();
    });

    // start animation and call onFinish only after animation completes
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // give a small pause so final frame is readable
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) widget.onFinish();
        });
      }
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // build a widget for each letter with individual staggered fade + wiggle
  Widget _animatedLetter(String char, int index) {
    // Start text animation after logo completes (0.55 onwards)
    final double start = 0.55 + index * 0.08;
    final double end = start + 0.4;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // opacity progress
        final raw = ((t - start) / (end - start)).clamp(0.0, 1.0);
        final opacity = Curves.easeIn.transform(raw);
        // translateY for smooth drop
        final translate = (1 - Curves.easeOut.transform(raw)) * 14.0;
        // wiggle: gentle sinus rotation diminishing as it settles
        final wiggleProgress = raw;
        final wiggle =
            sin(wiggleProgress * pi * 2) * (0.06) * (1 - wiggleProgress);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translate),
            child: Transform.rotate(
              angle: wiggle,
              child: child,
            ),
          ),
        );
      },
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          // safe fallback if custom font not loaded
          fontFamilyFallback: ['Roboto', 'Helvetica'],
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ensure white background, foreground image and animated title below
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Centered foreground image (user-provided). Place your icon at assets/mountain.png.
            Center(
              child: FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Image.asset(
                    'assets/icon.png',
                    width: MediaQuery.of(context).size.width * 0.46,
                    height: MediaQuery.of(context).size.width * 0.46,
                    fit: BoxFit.contain,
                    // show a visible fallback so you can see if asset failed
                    errorBuilder: (c, e, s) {
                      // helpful debug indicator instead of empty space
                      return const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.black26,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'mountain.png not found',
                            style: TextStyle(color: Colors.black26),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Title "Dew" below the image with individual letter animations (starts after logo)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _title.length,
                  (i) => _animatedLetter(_title[i], i),
                ),
              ),
            ),

            // Optional small tagline (appears after logo completes)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.08,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _taglineOpacity,
                child: const Text(
                  'Music Streaming & Sharing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),

            // Skip button
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black12,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => widget.onFinish(),
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}