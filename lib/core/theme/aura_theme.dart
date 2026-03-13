import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'aura_colors.dart';

class AuraTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuraColors.deepBlack,
      primaryColor: AuraColors.electricViolet,

      // Default font family
      fontFamily: GoogleFonts.outfit().fontFamily,

      textTheme:
          GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(
          color: AuraColors.white,
          fontWeight: FontWeight.bold,
          fontSize: 32,
          letterSpacing: -1.0,
        ),
        headlineMedium: const TextStyle(
          color: AuraColors.white,
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),
        bodyLarge: const TextStyle(
          color: AuraColors.white,
          fontSize: 16,
        ),
        bodyMedium: const TextStyle(
          color: AuraColors.white70,
          fontSize: 14,
        ),
      ),

      colorScheme: const ColorScheme.dark(
        primary: AuraColors.electricViolet,
        secondary: AuraColors.neonBlue,
        surface: AuraColors.almostBlack,
        background: AuraColors.deepBlack,
        error: AuraColors.error,
      ),

      iconTheme: const IconThemeData(
        color: AuraColors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AuraColors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AuraColors.almostBlack,
        selectedItemColor: AuraColors.electricViolet,
        unselectedItemColor: AuraColors.white38,
      ),
    );
  }
}
