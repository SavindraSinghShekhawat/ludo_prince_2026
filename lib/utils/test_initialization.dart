import 'package:ludo_prince/games/ludo/domain/models/token.dart';

enum InitialGameState {
  normal,
  almostWon,
  homeStretch,
  overlap2,
  overlap3,
  overlap4,
  overlap8,
  conflict,
}

class TestInitialization {
  static List<Token> applyTestState(
    List<Token> tokens,
    InitialGameState state,
  ) {
    if (state == InitialGameState.normal) return tokens;

    List<Token> newTokens = List.from(tokens);

    void safeSet(int idx, Token Function(Token) update) {
      if (idx < newTokens.length) {
        newTokens[idx] = update(newTokens[idx]);
      }
    }

    switch (state) {
      case InitialGameState.almostWon:
        safeSet(
          0,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          1,
          (t) => t.copyWith(state: TokenState.finished, position: 56),
        );
        safeSet(
          2,
          (t) => t.copyWith(state: TokenState.finished, position: 56),
        );
        safeSet(
          3,
          (t) => t.copyWith(state: TokenState.finished, position: 56),
        );
        break;
      case InitialGameState.homeStretch:
        safeSet(
          0,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          1,
          (t) => t.copyWith(state: TokenState.board, position: 50),
        );
        safeSet(
          2,
          (t) => t.copyWith(state: TokenState.board, position: 40),
        );
        safeSet(
          3,
          (t) => t.copyWith(state: TokenState.board, position: 49),
        );
        break;
      case InitialGameState.overlap2:
        safeSet(
          0,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          1,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          2,
          (t) => t.copyWith(state: TokenState.board, position: 40),
        );
        safeSet(
          3,
          (t) => t.copyWith(state: TokenState.board, position: 40),
        );
        break;
      case InitialGameState.overlap3:
        safeSet(
          0,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          1,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          2,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          3,
          (t) => t.copyWith(state: TokenState.board, position: 40),
        );
        break;
      case InitialGameState.overlap4:
        safeSet(
          0,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          1,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          2,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        safeSet(
          3,
          (t) => t.copyWith(state: TokenState.homeStretch, position: 54),
        );
        break;
      case InitialGameState.overlap8:
        if (tokens.isNotEmpty) {
          int position = 0;
          switch (tokens[0].slot) {
            case PlayerSlot.slot4:
              position = 15;
              break;
            case PlayerSlot.slot3:
              position = 2;
              break;
            case PlayerSlot.slot2:
              position = 41;
              break;
            case PlayerSlot.slot1:
              position = 28;
              break;
          }
          safeSet(
            0,
            (t) => t.copyWith(state: TokenState.board, position: position),
          );
          safeSet(
            1,
            (t) => t.copyWith(state: TokenState.board, position: position),
          );
          safeSet(
            2,
            (t) => t.copyWith(state: TokenState.board, position: 1),
          );
          safeSet(
            3,
            (t) => t.copyWith(state: TokenState.board, position: 1),
          );
        }
        break;
      case InitialGameState.conflict:
        safeSet(
          0,
          (t) => t.copyWith(state: TokenState.board, position: 15),
        );
        safeSet(
          1,
          (t) => t.copyWith(state: TokenState.board, position: 14),
        );
        break;
      default:
        break;
    }

    return newTokens;
  }
}
