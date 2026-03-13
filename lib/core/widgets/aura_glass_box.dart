import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dew/core/theme/aura_colors.dart';

class AuraGlassBox extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double opacity;
  final bool hasBorder;

  const AuraGlassBox({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.opacity = 0.1,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: hasBorder
                ? Border.all(color: Colors.white.withOpacity(0.1), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
