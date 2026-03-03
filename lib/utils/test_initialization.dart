import '../models/token.dart';

enum InitialGameState {
  normal,
  almostWon,
  homeStretch,
  conflict,
}


class TestInitialization {
  static List<Token> applyTestState(
      List<Token> tokens, InitialGameState state) {
    if (state == InitialGameState.normal) return tokens;

    List<Token> newTokens = List.from(tokens);

    switch (state) {
      case InitialGameState.almostWon:
        newTokens[0] =
            newTokens[0].copyWith(state: TokenState.homeStretch, position: 54);
        newTokens[1] =
            newTokens[1].copyWith(state: TokenState.finished, position: 56);
        newTokens[2] =
            newTokens[2].copyWith(state: TokenState.finished, position: 56);
        newTokens[3] =
            newTokens[3].copyWith(state: TokenState.finished, position: 56);
        break;
      case InitialGameState.homeStretch:
        newTokens[0] =
            newTokens[0].copyWith(state: TokenState.homeStretch, position: 54);
        newTokens[1] =
            newTokens[1].copyWith(state: TokenState.board, position: 50);
        newTokens[2] =
            newTokens[2].copyWith(state: TokenState.board, position: 40);
        newTokens[3] =
            newTokens[3].copyWith(state: TokenState.board, position: 49);
        break;
      case InitialGameState.conflict:
        newTokens[0] =
            newTokens[0].copyWith(state: TokenState.board, position: 15);
        newTokens[1] =
            newTokens[1].copyWith(state: TokenState.board, position: 14);
        break;
      default:
        break;
    }

    return newTokens;
  }
}
