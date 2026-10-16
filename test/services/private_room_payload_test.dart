import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/domain/engine/game_engine.dart';

void main() {
  group('Private Room / Play with Friends Payload Verification', () {
    test('Token JSON structure created by matchmaking service deserializes properly', () {
      final generatedTokens = [
        for (int i = 0; i < 4; i++)
          {'id': i, 'slot': 'slot1', 'position': 0, 'state': 'home'}
      ];

      final deserialized = generatedTokens.map((t) => Token.fromJson(t)).toList();

      expect(deserialized.length, 4);
      for (int i = 0; i < 4; i++) {
        expect(deserialized[i].id, i);
        expect(deserialized[i].slot, PlayerSlot.slot1);
        expect(deserialized[i].state, TokenState.home);
        expect(deserialized[i].position, 0);
      }
    });

    test('Turn order resolution for 2, 3, and 4 player private rooms', () {
      final slots2p = PlayerSlotExtension.getSlotsFor(2);
      expect(slots2p, [PlayerSlot.slot1, PlayerSlot.slot3]);

      final slots3p = PlayerSlotExtension.getSlotsFor(3);
      expect(slots3p, [PlayerSlot.slot1, PlayerSlot.slot4, PlayerSlot.slot3]);

      final slots4p = PlayerSlotExtension.getSlotsFor(4);
      expect(slots4p, [
        PlayerSlot.slot1,
        PlayerSlot.slot4,
        PlayerSlot.slot3,
        PlayerSlot.slot2,
      ]);
    });

    test('Engine move validation succeeds with private room initialized tokens', () {
      final engine = GameEngine();

      final homeToken = Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.home, position: 0);

      // On rolling 6, token can leave home
      expect(engine.isValidMove(homeToken, 6), isTrue);
      // On rolling anything else, cannot leave home
      expect(engine.isValidMove(homeToken, 1), isFalse);
      expect(engine.isValidMove(homeToken, 5), isFalse);

      // Step out to board
      final boardToken = Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 0);
      expect(engine.isValidMove(boardToken, 4), isTrue);
    });

    test('Simulate player snapshot reconstruction with new private room payload', () {
      final firebaseSnapshot = {
        'status': 'playing',
        'currentTurn': 'slot1',
        'turnOrder': ['slot1', 'slot3'],
        'prefetchedSeed': 456789,
        'players': {
          'slot1': {
            'uid': 'userA',
            'name': 'HostPlayer',
            'skipCount': 0,
            'sixPity': 0,
            'tokens': [
              for (int i = 0; i < 4; i++)
                {'id': i, 'slot': 'slot1', 'position': 0, 'state': 'home'}
            ],
          },
          'slot3': {
            'uid': 'userB',
            'name': 'FriendPlayer',
            'skipCount': 0,
            'sixPity': 0,
            'tokens': [
              for (int i = 0; i < 4; i++)
                {'id': i, 'slot': 'slot3', 'position': 0, 'state': 'home'}
            ],
          },
        },
      };

      final playersMap = firebaseSnapshot['players'] as Map<String, dynamic>;
      final players = <Player>[];

      for (var entry in playersMap.entries) {
        final slot = PlayerSlot.values.firstWhere((e) => e.name == entry.key);
        final pData = entry.value as Map<String, dynamic>;
        final rawTokens = pData['tokens'] as List;

        final tokens = rawTokens.map((t) => Token.fromJson(Map<String, dynamic>.from(t as Map))).toList();

        players.add(Player(
          slot: slot,
          name: pData['name'] as String,
          sixPity: pData['sixPity'] as int,
          skipCount: pData['skipCount'] as int,
          tokens: tokens,
        ));
      }

      expect(players.length, 2);
      expect(players[0].slot, PlayerSlot.slot1);
      expect(players[0].tokens.length, 4);
      expect(players[0].tokens.first.state, TokenState.home);

      expect(players[1].slot, PlayerSlot.slot3);
      expect(players[1].tokens.length, 4);
      expect(players[1].tokens.first.state, TokenState.home);
    });
  });
}
