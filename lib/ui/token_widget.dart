import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/models/game_state.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import '../models/token.dart';
import '../models/board_path.dart';

class TokenWidget extends ConsumerWidget {
  final Token token;
  final double cellSize;

  const TokenWidget({super.key, required this.token, required this.cellSize});

  bool _isMoveValid(Token t, GameState state) {
    if (t.state == TokenState.home) return state.diceValue == 6;
    if (t.state == TokenState.finished) return false;
    return t.position + state.diceValue <= 56;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(gameStreamProvider);
    final gameState = asyncState.value;
    if (gameState == null) return const SizedBox();
    final isTurn = gameState.currentTurn == token.slot;
    final isMovable =
        isTurn && gameState.isDiceRolled && _isMoveValid(token, gameState);

    Offset gridPos = BoardPath.getTokenOffset(token);

    // Tokens in base should be spread out within the 6x6 base square
    // Tokens on the path or home stretch must be exactly centered in a 1x1 cell

    double tokenSize =
        cellSize * 0.7; // Make token slightly smaller than cell for padding
    double offsetXY = (cellSize - tokenSize) / 2;

    // Handle stacking multiple tokens on the same spot
    double overlapOffsetX = 0;
    double overlapOffsetY = 0;

    if (token.state != TokenState.home) {
      List<Token> overlappingTokens = [];

      if (token.state == TokenState.board) {
        int myAbsPos =
            BoardPath.getAbsolutePosition(token.slot, token.position);
        overlappingTokens =
            gameState.players.expand((p) => p.tokens).where((t) {
          if (t.state != TokenState.board) return false;
          return BoardPath.getAbsolutePosition(t.slot, t.position) == myAbsPos;
        }).toList();
      } else {
        // Home stretch or finished, only overlaps with same color
        overlappingTokens = gameState.players
            .firstWhere((p) => p.slot == token.slot)
            .tokens
            .where(
                (t) => t.state == token.state && t.position == token.position)
            .toList();
      }

      if (overlappingTokens.length > 1) {
        int index = overlappingTokens
            .indexWhere((t) => t.slot == token.slot && t.id == token.id);
        double spread = tokenSize * 0.3; // 30% shift

        if (overlappingTokens.length == 2) {
          // Side-by-side
          overlapOffsetX = (index == 0) ? -spread / 1.5 : spread / 1.5;
          overlapOffsetY = 0;
        } else if (overlappingTokens.length == 3) {
          // Triangle
          if (index == 0) {
            overlapOffsetX = 0;
            overlapOffsetY = -spread;
          } else if (index == 1) {
            overlapOffsetX = -spread;
            overlapOffsetY = spread;
          } else {
            overlapOffsetX = spread;
            overlapOffsetY = spread;
          }
        } else if (overlappingTokens.length == 4) {
          // Arrange 4 tokens in a small square
          overlapOffsetX = (index % 2 == 1) ? spread : -spread;
          overlapOffsetY = (index % 4 >= 2) ? spread : -spread;
        } else {
          // 5+ tokens: arrange in a 3x3 (up to 9) or denser grid
          double multiSpread = spread * 0.8; // tighter spread
          int cols =
              (overlappingTokens.length > 4 && overlappingTokens.length <= 6)
                  ? 3
                  : 4;
          int row = index ~/ cols;
          int col = index % cols;
          overlapOffsetX = (col - (cols - 1) / 2) * multiSpread;
          overlapOffsetY =
              (row - (overlappingTokens.length / cols).ceil() / 2 + 0.5) *
                  multiSpread;
        }

        // Scale down slightly when stacked to fit better
        tokenSize *= (overlappingTokens.length > 4) ? 0.6 : 0.8;
        offsetXY = (cellSize - tokenSize) / 2;
      }
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      left: gridPos.dx * cellSize + offsetXY + overlapOffsetX,
      top: gridPos.dy * cellSize + offsetXY + overlapOffsetY,
      width: tokenSize,
      height: tokenSize,
      child: IgnorePointer(
        ignoring: !isMovable,
        child: GestureDetector(
          onTap: () {
            ref.read(gameControllerProvider).sendMoveIntent(token);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColor(token.slot),
              border: Border.all(
                  color: isMovable ? Colors.white : Colors.white60,
                  width: isMovable ? 3 : 1.5),
              boxShadow: [
                BoxShadow(
                  color: isMovable
                      ? _getColor(token.slot).withValues(alpha: 0.8)
                      : Colors.black.withValues(alpha: 0.4),
                  blurRadius: isMovable ? 8 : 4,
                  spreadRadius: isMovable ? 2 : 0,
                  offset: const Offset(0, 2),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor(PlayerSlot pSlot) {
    switch (pSlot) {
      case PlayerSlot.slot1:
        return Colors.red;
      case PlayerSlot.slot2:
        return Colors.green;
      case PlayerSlot.slot3:
        return Colors.amber;
      case PlayerSlot.slot4:
        return Colors.blue;
    }
  }
}
