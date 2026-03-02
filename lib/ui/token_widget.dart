import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/token.dart';
import '../models/board_path.dart';
import '../providers/game_state_provider.dart';

class TokenWidget extends ConsumerWidget {
  final Token token;
  final double cellSize;

  const TokenWidget({super.key, required this.token, required this.cellSize});

  bool _isMoveValid(Token t, GameState state) {
    if (t.state == TokenState.home) return state.diceValue == 6;
    if (t.state == TokenState.finished) return false;
    if (t.state == TokenState.homeStretch) return t.position + state.diceValue <= 57;
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final isTurn = gameState.currentTurn == token.color;
    final isMovable = isTurn && gameState.isDiceRolled && _isMoveValid(token, gameState);

    Offset gridPos = BoardPath.getTokenOffset(token);
    
    // Tokens in base should be spread out within the 6x6 base square
    // Tokens on the path or home stretch must be exactly centered in a 1x1 cell
    
    double tokenSize = cellSize * 0.7; // Make token slightly smaller than cell for padding
    double offsetXY = (cellSize - tokenSize) / 2;

    // Handle stacking multiple tokens on the same spot
    double overlapOffsetX = 0;
    double overlapOffsetY = 0;
    
    if (token.state != TokenState.home) {
      List<Token> overlappingTokens = [];
      
      if (token.state == TokenState.board) {
        int myAbsPos = BoardPath.getAbsolutePosition(token.color, token.position);
        overlappingTokens = gameState.players.expand((p) => p.tokens).where((t) {
          if (t.state != TokenState.board) return false;
          return BoardPath.getAbsolutePosition(t.color, t.position) == myAbsPos;
        }).toList();
      } else {
        // Home stretch or finished, only overlaps with same color
        overlappingTokens = gameState.players
            .firstWhere((p) => p.color == token.color)
            .tokens
            .where((t) => t.state == token.state && t.position == token.position)
            .toList();
      }
          
      if (overlappingTokens.length > 1) {
        int index = overlappingTokens.indexWhere((t) => t.color == token.color && t.id == token.id);
        double spread = tokenSize * 0.3; // 30% shift
        
        // Arrange up to 4 tokens in a small square, and wrap if there's more (though rare in small grid)
        overlapOffsetX = (index % 2 == 1) ? spread : -spread;
        overlapOffsetY = (index % 4 >= 2) ? spread : -spread; 
        
        // Scale down slightly when stacked to fit better
        tokenSize *= 0.8;
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
      child: GestureDetector(
        onTap: () {
          ref.read(gameStateProvider.notifier).moveToken(token);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getColor(token.color),
            border: Border.all(
              color: isMovable ? Colors.white : Colors.white60, 
              width: isMovable ? 3 : 1.5
            ),
            boxShadow: [
              BoxShadow(
                color: isMovable ? _getColor(token.color).withOpacity(0.8) : Colors.black.withOpacity(0.4),
                blurRadius: isMovable ? 8 : 4,
                spreadRadius: isMovable ? 2 : 0,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor(PlayerColor pColor) {
    switch (pColor) {
      case PlayerColor.red: return Colors.red;
      case PlayerColor.green: return Colors.green;
      case PlayerColor.yellow: return Colors.amber;
      case PlayerColor.blue: return Colors.blue;
    }
  }
}
