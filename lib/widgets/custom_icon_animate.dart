import 'package:flutter/material.dart';

class InteractiveAnimatedIcon extends StatefulWidget {
  @override
  _InteractiveAnimatedIconState createState() => _InteractiveAnimatedIconState();
}

class _InteractiveAnimatedIconState extends State<InteractiveAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();

    // Initialize the AnimationController
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300), // Duration of the animation
      vsync: this,
    )..addListener(() {
        setState(() {});
      });

    // Define the animation
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // Curve of the animation
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _animation,
        child: Icon(
          Icons.music_note, // Replace with your custom icon
          size: 30.0,
          color: Colors.white,
        ),
      ),
    );
  }

  void _handleTap() {
    setState(() {
      _isTapped = !_isTapped;
      if (_isTapped) {
        _controller.forward(); // Start animation
      } else {
        _controller.reverse(); // Reverse animation
      }
    });
  }
}
