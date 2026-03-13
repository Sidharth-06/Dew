import 'package:flutter/material.dart';

class AuraColors {
  // Core Backgrounds
  static const Color deepBlack = Color(0xFF000000);
  static const Color almostBlack = Color(0xFF0A0A0A);
  static const Color surfaceLight = Color(0xFF1A1A1A);
  static const Color darkGlass = Color(0x99000000);

  // Accents
  static const Color electricViolet = Color(0xFF8B5CF6);
  static const Color neonBlue = Color(0xFF3B82F6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color hotPink = Color(0xFFEC4899);
  static const Color deepPurple = Color(0xFF4C1D95);

  // Functional
  static const Color white = Colors.white;
  static const Color white70 = Colors.white70;
  static const Color white38 = Colors.white38;
  static const Color transparent = Colors.transparent;

  static const Color error = Color(0xFFFF4848);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [electricViolet, deepPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coolGradient = LinearGradient(
    colors: [neonBlue, Color(0xFF21D4FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFBDA61), Color(0xFFFF5ACD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<LinearGradient> get genreGradients => [
        const LinearGradient(
            colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        const LinearGradient(
            colors: [Color(0xFF0093E9), Color(0xFF80D0C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        const LinearGradient(
            colors: [Color(0xFF4158D0), Color(0xFFC850C0), Color(0xFFFFCC70)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        const LinearGradient(
            colors: [Color(0xFF00DBDE), Color(0xFFFC00FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        const LinearGradient(
            colors: [Color(0xFFFBAB7E), Color(0xFFF7CE68)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        const LinearGradient(
            colors: [Color(0xFF85FFBD), Color(0xFFFFFB7D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ];
}
