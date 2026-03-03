import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/controllers/local_game_controller.dart';
import 'package:ludo_prince/models/token.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'ludo_screen.dart';
import '../models/initial_game_state.dart';
import 'rules_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _controllers.values.forEach((c) => c.dispose());
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
      return [PlayerSlot.slot4, PlayerSlot.slot2];
    } else if (numPlayers == 3) {
      return [PlayerSlot.slot4, PlayerSlot.slot2, PlayerSlot.slot1];
    } else {
      return [
        PlayerSlot.slot4,
        PlayerSlot.slot3,
        PlayerSlot.slot2,
        PlayerSlot.slot1
      ];
    }
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSlots = _getActiveSlots(_numPlayers);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Local Multiplayer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Select Number of Players',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [2, 3, 4].map((n) {
                      final isSelected = _numPlayers == n;
                      return ChoiceChip(
                        label: Text('$n Players',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected && _numPlayers != n) {
                            setState(() {
                              _numPlayers = n;
                              _initControllers();
                            });
                          }
                        },
                        selectedColor: Colors.blueAccent,
                        labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70),
                        backgroundColor: const Color(0xFF2A2A3D),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Player Names',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ...activeSlots.map((slot) {
                    Color displayColor = Colors.white;
                    switch (slot) {
                      case PlayerSlot.slot1:
                        displayColor = Colors.redAccent;
                        break;
                      case PlayerSlot.slot2:
                        displayColor = Colors.greenAccent.shade700;
                        break;
                      case PlayerSlot.slot3:
                        displayColor = Colors.amber.shade600;
                        break;
                      case PlayerSlot.slot4:
                        displayColor = Colors.blueAccent;
                        break;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[slot],
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText:
                                    'Player ${activeSlots.indexOf(slot) + 1}',
                                labelStyle: TextStyle(color: displayColor),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: displayColor.withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: displayColor, width: 2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                prefixIcon: Icon(
                                    (_isBotConfig[slot] ?? false)
                                        ? Icons.smart_toy
                                        : Icons.person,
                                    color: displayColor),
                                filled: true,
                                fillColor: const Color(0xFF2A2A3D),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              const Text('Bot',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Switch(
                                value: _isBotConfig[slot] ?? false,
                                activeColor: displayColor,
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
                    );
                  }).toList(),
                  const SizedBox(height: 40),
                  const Text(
                    'Initial Game State (Testing)',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<InitialGameState>(
                    value: _initialState,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF2A2A3D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: const Color(0xFF2A2A3D),
                    style: const TextStyle(color: Colors.white),
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
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: Colors.blueAccent.withOpacity(0.5),
                    ),
                    onPressed: () async {
                      Map<PlayerSlot, PlayerSetupConfig> config = {};
                      for (var slot in activeSlots) {
                        final text = _controllers[slot]!.text.trim();
                        final name = text.isEmpty
                            ? "Player ${activeSlots.indexOf(slot) + 1}"
                            : text;
                        config[slot] = PlayerSetupConfig(
                          name: name,
                          isBot: _isBotConfig[slot] ?? false,
                        );
                      }

                      await audioService.playStart();

                      if (!mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => ProviderScope(
                            overrides: [
                              gameControllerProvider.overrideWithValue(
                                  LocalGameController(config,
                                      initialState: _initialState)),
                            ],
                            child: const LudoScreen(),
                          ),
                        ),
                      );
                    },
                    child: const Text('Start Game',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
