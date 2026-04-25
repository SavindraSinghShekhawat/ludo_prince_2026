import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ludo_prince/utils/colors.dart';

/// Centralised theme builder for the entire app.
class AppTheme {
  AppTheme._();

  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryCyan,
        brightness: Brightness.dark,
        surface: AppColors.systemSurface,
        primary: AppColors.primaryCyan,
        secondary: AppColors.midnightSapphire,
      ),
      scaffoldBackgroundColor: AppColors.systemBackground,
      textTheme:
          GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: 1.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.starPlatinum,
          foregroundColor: AppColors.systemBackground,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.systemSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: Colors.white70,
          fontSize: 16,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.primaryCyan.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
    );
  }
}
