import 'package:flutter/foundation.dart';

@immutable
class GameRules {
  /// Whether tokens can exit the base on a roll of 1 as well as 6.
  final bool openOnOneAndSix;

  /// Number of tokens each player starts with (4 for standard, 2 for quick/blitz match).
  final int tokensPerPlayer;

  /// Whether rolling three consecutive 6s skips the player's turn.
  final bool penalizeThreeSixes;

  const GameRules({
    this.openOnOneAndSix = false,
    this.tokensPerPlayer = 4,
    this.penalizeThreeSixes = true,
  });

  /// True if any rule differs from standard classical Ludo rules.
  bool get isCustom =>
      openOnOneAndSix || tokensPerPlayer != 4 || !penalizeThreeSixes;

  GameRules copyWith({
    bool? openOnOneAndSix,
    int? tokensPerPlayer,
    bool? penalizeThreeSixes,
  }) {
    return GameRules(
      openOnOneAndSix: openOnOneAndSix ?? this.openOnOneAndSix,
      tokensPerPlayer: tokensPerPlayer ?? this.tokensPerPlayer,
      penalizeThreeSixes: penalizeThreeSixes ?? this.penalizeThreeSixes,
    );
  }

  Map<String, dynamic> toJson() => {
        "openOnOneAndSix": openOnOneAndSix,
        "tokensPerPlayer": tokensPerPlayer,
        "penalizeThreeSixes": penalizeThreeSixes,
      };

  factory GameRules.fromJson(Map<String, dynamic> json) {
    return GameRules(
      openOnOneAndSix: json["openOnOneAndSix"] ?? false,
      tokensPerPlayer: json["tokensPerPlayer"] ?? 4,
      penalizeThreeSixes: json["penalizeThreeSixes"] ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameRules &&
          runtimeType == other.runtimeType &&
          openOnOneAndSix == other.openOnOneAndSix &&
          tokensPerPlayer == other.tokensPerPlayer &&
          penalizeThreeSixes == other.penalizeThreeSixes;

  @override
  int get hashCode => Object.hash(
        openOnOneAndSix,
        tokensPerPlayer,
        penalizeThreeSixes,
      );
}
