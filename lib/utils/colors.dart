import 'package:flutter/material.dart';

class AppColors {
  // Royale Player Colors (Deep, sophisticated tones)
  static const Color player1Blue = Color(0xFF1465BF); // Royal Blue 800
  static const Color player2Yellow = Color(0xFFC88613); // Yellow 800 (Gold)
  static const Color player3Green = Color(0xFF177A1D); // Green 800 (Emerald)
  static const Color player4Red = Color(0xFFBD1010); // Red 800 (Imperial)

  // Glow Colors (Lighter variants for highlights and shadows)
  static const Color player1BlueGlow = Color(0xFF42A5F5);
  static const Color player2YellowGlow = Color(0xFFF8CF4C);
  static const Color player3GreenGlow = Color(0xFF7CE481);
  static const Color player4RedGlow = Color(0xFFEC524F);

  // Board Glassmorphism
  static const Color boardGlassBackground =
      Color(0xD9F3F3F3); // 85% White (Balance between whitish and visible)
  static const Color boardGlassBorder =
      Color(0x33000000); // Subtle dark border for definition
  static const Color boardGridColor =
      Color(0x1F000000); // Light grey grid for visibility (12% black)
  static const double boardGlassBlur = 12.0;

  // Board Opacities (Refined for a lighter look with visible grid)
  static const double boardBaseAlpha = 0.42;
  static const double boardBaseBorderAlpha = 0.5;
  static const double boardCellAlpha = 0.62;
  static const double boardHomeStretchAlpha = 0.55;
  static const double boardStartCellAlpha = 0.65;

  // Token Styling
  static const double tokenOpacity = 1.0;
  static const double tokenBorderOpacity = 0.8;
  static const double tokenReflectionAlpha = 0.4;

  // Star Styling
  static const Color starPlatinum = Color(0xFFD9E0E7); // Icy Royale Platinum
  static const Color starPlatinumGlow =
      Color(0x4D000000); // Subtle White Frost Glow
  static const Color starCellBackground =
      Color(0x1F000000); // 12% Black for visibility
}
