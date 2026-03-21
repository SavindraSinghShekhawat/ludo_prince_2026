import 'package:flutter/material.dart';
import '../models/token.dart';

class AppColors {
  // Royale Player Colors (Deep, sophisticated tones)
  static const Color player1Blue = Color(0xFF0D47A1); // Deeper Royal Blue
  static const Color player2Yellow = Color(0xFFA06A0B); // Deeper Gold
  static const Color player3Green = Color(0xFF0D5312); // Deep Forest Green
  static const Color player4Red = Color(0xFF8B0000); // Darker Imperial Red

  // Glow Colors (Lighter variants for highlights and shadows)
  static const Color player1BlueGlow = Color(0xFF1976D2);
  static const Color player2YellowGlow = Color(0xFFC88613);
  static const Color player3GreenGlow = Color(0xFF2E7D32);
  static const Color player4RedGlow = Color(0xFFC62828);

  // UI Colors (Lighter, more vibrant versions for icons/setup)
  static const Color player1BlueUI = Color(0xFF347DF1); // Blue 400
  static const Color player2YellowUI = Color(0xFFBA8421); // Amber 400
  static const Color player3GreenUI = Color(0xFF238F2B); // Green 400
  static const Color player4RedUI = Color(0xFFBA2B2B); // Red 400

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
  static const double boardHomeStretchAlpha = 0.58;
  static const double boardStartCellAlpha = 0.62;

  // Token Styling
  static const double tokenOpacity = 1.0;
  static const double tokenBorderOpacity = 1.0;
  static const double tokenReflectionAlpha = 0.18;

  // Star Styling
  static const Color starPlatinum = Color(0xFFD9E0E7); // Icy Royale Platinum
  static const Color starPlatinumGlow =
      Color(0x4D000000); // Subtle White Frost Glow
  static const Color starCellBackground =
      Color(0x1F000000); // 12% Black for visibility

  // Helper methods to get color by slot
  static Color getColorForSlot(PlayerSlot slot) {
    switch (slot) {
      case PlayerSlot.slot1:
        return player1Blue;
      case PlayerSlot.slot2:
        return player2Yellow;
      case PlayerSlot.slot3:
        return player3Green;
      case PlayerSlot.slot4:
        return player4Red;
    }
  }

  static Color getGlowColorForSlot(PlayerSlot slot) {
    switch (slot) {
      case PlayerSlot.slot1:
        return player1BlueGlow;
      case PlayerSlot.slot2:
        return player2YellowGlow;
      case PlayerSlot.slot3:
        return player3GreenGlow;
      case PlayerSlot.slot4:
        return player4RedGlow;
    }
  }

  static Color getUiColorForSlot(PlayerSlot slot) {
    switch (slot) {
      case PlayerSlot.slot1:
        return player1BlueUI;
      case PlayerSlot.slot2:
        return player2YellowUI;
      case PlayerSlot.slot3:
        return player3GreenUI;
      case PlayerSlot.slot4:
        return player4RedUI;
    }
  }
}
