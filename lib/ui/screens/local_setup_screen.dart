import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/ludo_controller.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/models/token.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/utils/test_initialization.dart';
import 'ludo_screen.dart';
import '../dialogs/rules_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LocalSetupScreen extends ConsumerStatefulWidget {
  const LocalSetupScreen({super.key});

  @override
  ConsumerState<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends ConsumerState<LocalSetupScreen> {
  int _numPlayers = 2;
  final Map<PlayerSlot, TextEditingController> _controllers = {};
  final Map<PlayerSlot, bool> _isBotConfig = {};
  InitialGameState _initialState = InitialGameState.normal;

  // Platinum Style Constants
  static const Color platinumColor = Color(0xFFE5E4E2);
  static const Color darkBackground = Color(0xFF1E1E2C);
  static const Color surfaceColor = Color(0xFF2A2A3D);

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _isBotConfig.clear();

    final slots = _getActiveSlots(_numPlayers);
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      _controllers[slot] = TextEditingController(text: "Player ${i + 1}");
      _isBotConfig[slot] = false;
    }
  }

  List<PlayerSlot> _getActiveSlots(int numPlayers) {
    if (numPlayers == 2) {
      return [PlayerSlot.slot1, PlayerSlot.slot3];
    } else if (numPlayers == 3) {
      return [PlayerSlot.slot1, PlayerSlot.slot3, PlayerSlot.slot4];
    } else {
      return [
        PlayerSlot.slot1,
        PlayerSlot.slot2,
        PlayerSlot.slot3,
        PlayerSlot.slot4
      ];
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSlots = _getActiveSlots(_numPlayers);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'LOCAL MULTIPLAYER',
          style: TextStyle(
            color: platinumColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: platinumColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const RulesDialog(),
              );
            },
            tooltip: 'Game Rules',
          ),
        ],
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              surfaceColor.withValues(alpha: 0.4),
              darkBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: platinumColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'NUMBER OF PLAYERS',
                      style: TextStyle(
                        color: platinumColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [2, 3, 4].map((n) {
                        final isSelected = _numPlayers == n;
                        return InkWell(
                          onTap: () {
                            if (_numPlayers != n) {
                              setState(() {
                                _numPlayers = n;
                                _initControllers();
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? platinumColor : Colors.black26,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color:
                                    isSelected ? Colors.white : Colors.white10,
                                width: 2,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: platinumColor.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                              ],
                            ),
                            child: Text(
                              '$n',
                              style: TextStyle(
                                color: isSelected
                                    ? darkBackground
                                    : Colors.white54,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                            .animate(target: isSelected ? 1 : 0)
                            .scale(begin: const Offset(0.9, 0.9));
                      }).toList(),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'PLAYER NAMES',
                      style: TextStyle(
                        color: platinumColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ...activeSlots.map((slot) {
                      Color displayColor = Colors.white;
                      switch (slot) {
                        case PlayerSlot.slot1:
                          displayColor = Colors.blueAccent;
                          break;
                        case PlayerSlot.slot2:
                          displayColor = Colors.amber.shade600;
                          break;
                        case PlayerSlot.slot3:
                          displayColor = Colors.greenAccent.shade700;
                          break;
                        case PlayerSlot.slot4:
                          displayColor = Colors.redAccent;
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controllers[slot],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText:
                                      'PLAYER ${activeSlots.indexOf(slot) + 1}',
                                  labelStyle: TextStyle(
                                      color:
                                          displayColor.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        const BorderSide(color: Colors.white10),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: displayColor, width: 2),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  prefixIcon: Icon(
                                    (_isBotConfig[slot] ?? false)
                                        ? Icons.smart_toy
                                        : Icons.person,
                                    color: displayColor.withValues(alpha: 0.8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.black26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                const Text('BOT',
                                    style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                Switch(
                                  value: _isBotConfig[slot] ?? false,
                                  activeColor: displayColor,
                                  activeTrackColor:
                                      displayColor.withValues(alpha: 0.3),
                                  inactiveThumbColor: Colors.white54,
                                  inactiveTrackColor: Colors.white10,
                                  onChanged: (val) {
                                    setState(() {
                                      _isBotConfig[slot] = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: (activeSlots.indexOf(slot) * 100).ms)
                          .slideX(begin: -0.1);
                    }),
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      DropdownButtonFormField<InitialGameState>(
                        value: _initialState,
                        decoration: InputDecoration(
                          labelText: "INITIAL STATE (DEBUG)",
                          labelStyle: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                        ),
                        dropdownColor: surfaceColor,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        items: InitialGameState.values.map((state) {
                          return DropdownMenuItem(
                            value: state,
                            child: Text(state.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _initialState = val;
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 40),
                    _buildPlatinumButton(
                      onPressed: () async {
                        Map<PlayerSlot, PlayerSetupConfig> config = {};
                        for (var slot in activeSlots) {
                          final text = _controllers[slot]!.text.trim();
                          final name = text.isEmpty
                              ? "Player ${activeSlots.indexOf(slot) + 1}"
                              : text;
                          config[slot] = PlayerSetupConfig(
                            name: name,
                            type: (_isBotConfig[slot] ?? false)
                                ? PlayerType.localBot
                                : PlayerType.localHuman,
                          );
                        }

                        await audioService.playStart();

                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (childContext) => ProviderScope(
                              overrides: [
                                gameControllerProvider.overrideWithValue(
                                    LudoController(config,
                                        initialState: _initialState)),
                              ],
                              child: const LudoScreen(),
                            ),
                          ),
                        );
                      },
                      text: "START GAME",
                      color: Colors.greenAccent.shade700,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.95, 0.95)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlatinumButton({
    required VoidCallback onPressed,
    required String text,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2), width: 1)),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
