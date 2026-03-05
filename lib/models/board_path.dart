import 'dart:ui';
import 'token.dart';

class BoardPath {
  static const List<int> safeRelativeSpots = [0, 8, 13, 21, 26, 34, 39, 47];

  static bool isSafeSpot(int relativePosition) {
    return safeRelativeSpots.contains(relativePosition);
  }

  static int getAbsolutePosition(PlayerSlot slot, int relativePosition) {
    if (relativePosition > 51) return -1;
    int startAbsolute;
    switch (slot) {
      case PlayerSlot.slot4:
        startAbsolute = 0;
        break; // Starts at bottom-left path of the left arm
      case PlayerSlot.slot3:
        startAbsolute = 13;
        break; // Starts at top-left path of the top arm
      case PlayerSlot.slot2:
        startAbsolute = 26;
        break; // Starts at top-right path of the right arm
      case PlayerSlot.slot1:
        startAbsolute = 39;
        break; // Starts at bottom-right path of the bottom arm
    }
    return (startAbsolute + relativePosition) % 52;
  }

  // Map 0-51 to (col, row) on the 15x15 grid.
  // 0 is Red's start: col 1, row 6.
  static final List<Offset> absolutePathCoordinates = [
    // Left arm (top row, moving right)
    const Offset(1, 6), const Offset(2, 6), const Offset(3, 6),
    const Offset(4, 6), const Offset(5, 6),
    // Top arm (left column, moving up)
    const Offset(6, 5), const Offset(6, 4), const Offset(6, 3),
    const Offset(6, 2), const Offset(6, 1), const Offset(6, 0),
    // Top arm (top row, moving right)
    const Offset(7, 0), const Offset(8, 0),
    // Top arm (right column, moving down)
    const Offset(8, 1), const Offset(8, 2), const Offset(8, 3),
    const Offset(8, 4), const Offset(8, 5),
    // Right arm (top row, moving right)
    const Offset(9, 6), const Offset(10, 6), const Offset(11, 6),
    const Offset(12, 6), const Offset(13, 6), const Offset(14, 6),
    // Right arm (right column, moving down)
    const Offset(14, 7), const Offset(14, 8),
    // Right arm (bottom row, moving left)
    const Offset(13, 8), const Offset(12, 8), const Offset(11, 8),
    const Offset(10, 8), const Offset(9, 8),
    // Bottom arm (right column, moving down)
    const Offset(8, 9), const Offset(8, 10), const Offset(8, 11),
    const Offset(8, 12), const Offset(8, 13), const Offset(8, 14),
    // Bottom arm (bottom row, moving left)
    const Offset(7, 14), const Offset(6, 14),
    // Bottom arm (left column, moving up)
    const Offset(6, 13), const Offset(6, 12), const Offset(6, 11),
    const Offset(6, 10), const Offset(6, 9),
    // Left arm (bottom row, moving left)
    const Offset(5, 8), const Offset(4, 8), const Offset(3, 8),
    const Offset(2, 8), const Offset(1, 8), const Offset(0, 8),
    // Left arm (left column, moving up)
    const Offset(0, 7), const Offset(0, 6)
  ];

  static Offset getHomeStretchCoordinate(
      PlayerSlot slot, int relativePosition) {
    // relativePosition 51-55 are home stretch, 56 is center.
    int step = relativePosition - 50; // 1 to 6
    if (step == 6) {
      switch (slot) {
        case PlayerSlot.slot4:
          return const Offset(6.2, 7); // Inside left triangle
        case PlayerSlot.slot3:
          return const Offset(7, 6.2); // Inside top triangle
        case PlayerSlot.slot2:
          return const Offset(7.8, 7); // Inside right triangle
        case PlayerSlot.slot1:
          return const Offset(7, 7.8); // Inside bottom triangle
      }
    }

    switch (slot) {
      case PlayerSlot.slot4:
        return Offset(step.toDouble(), 7); // (1,7) to (5,7)
      case PlayerSlot.slot3:
        return Offset(7, step.toDouble()); // (7,1) to (7,5)
      case PlayerSlot.slot2:
        return Offset(14 - step.toDouble(), 7); // (13,7) to (9,7)
      case PlayerSlot.slot1:
        return Offset(7, 14 - step.toDouble()); // (7,13) to (7,9)
    }
  }

  static Offset getBaseCoordinate(PlayerSlot slot, int tokenId) {
    // The exact token positions should sit aesthetically inside the base square.
    // The white inner box spans 4 cells. Its center aligns with specific coordinates.
    // By giving these exactly mathematically spaced center coordinates, the TokenWidget
    // will center perfectly on these points.
    double bx, by;
    switch (slot) {
      case PlayerSlot.slot4:
        bx = 2.5;
        by = 2.5;
        break;
      case PlayerSlot.slot3:
        bx = 11.5;
        by = 2.5;
        break;
      case PlayerSlot.slot2:
        bx = 11.5;
        by = 11.5;
        break;
      case PlayerSlot.slot1:
        bx = 2.5;
        by = 11.5;
        break;
    }

    // Spread tokens perfectly into the 4 quadrants of the white box
    double spread = 1.0;
    if (tokenId == 0) return Offset(bx - spread, by - spread);
    if (tokenId == 1) return Offset(bx + spread, by - spread);
    if (tokenId == 2) return Offset(bx - spread, by + spread);
    return Offset(bx + spread, by + spread);
  }

  static Offset getTokenOffset(Token token) {
    if (token.state == TokenState.home) {
      return getBaseCoordinate(token.slot, token.id);
    }
    if (token.state == TokenState.board) {
      int absPos = getAbsolutePosition(token.slot, token.position);
      return absolutePathCoordinates[absPos];
    }
    if (token.state == TokenState.homeStretch ||
        token.state == TokenState.finished) {
      return getHomeStretchCoordinate(token.slot, token.position);
    }
    return const Offset(0, 0);
  }
}
