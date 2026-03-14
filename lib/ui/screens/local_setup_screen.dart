import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/ui/widgets/robot_icon.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/utils/test_initialization.dart';
import 'ludo_screen.dart';
import '../dialogs/rules_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../../models/game_state.dart';
import '../../controllers/ludo_controller.dart';
import '../../models/token.dart';

class LocalSetupScreen extends ConsumerStatefulWidget {
  const LocalSetupScreen({super.key});

  @override
  ConsumerState<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends ConsumerState<LocalSetupScreen> {
  int _numPlayers = 2;
  final Map<PlayerSlot, TextEditingController> _controllers = {};
  Map<PlayerSlot, bool> _isBotConfig = {};
  InitialGameState _initialState = InitialGameState.normal;
  GameMode _gameMode = GameMode.classic;

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
    if (_numPlayers != 4) {
      _gameMode = GameMode.classic;
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
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Offline & Bot Play',
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
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const SettingsDialog(),
              );
            },
            tooltip: 'Settings',
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
                        checkmarkColor: const Color(0xFF1E1E2C),
                        onSelected: (selected) {
                          if (selected && _numPlayers != n) {
                            setState(() {
                              _numPlayers = n;
                              // Force Classic mode if players < 4
                              if (_numPlayers < 4) {
                                _gameMode = GameMode.classic;
                              }
                              _initControllers();
                            });
                          }
                        },
                        selectedColor: const Color(0xFFE5E4E2),
                        labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF1E1E2C)
                                : Colors.white70),
                        backgroundColor: const Color(0xFF2A2A3D),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Select Game Mode',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGameModeChip(
                        mode: GameMode.classic,
                        label: 'Classic',
                        description: 'Standard Rules',
                        icon: Icons.person,
                        isEnabled: true,
                      ),
                      const SizedBox(width: 16),
                      _buildGameModeChip(
                        mode: GameMode.team,
                        label: '2vs2 Team',
                        description: 'Requires 4 Players',
                        icon: Icons.group,
                        isEnabled: _numPlayers == 4,
                      ),
                    ],
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
                  ...(() {
                    List<PlayerSlot> displaySlots = List.from(activeSlots);
                    bool isTeam =
                        _gameMode == GameMode.team && _numPlayers == 4;

                    if (isTeam) {
                      displaySlots = [
                        PlayerSlot.slot1,
                        PlayerSlot.slot3,
                        PlayerSlot.slot2,
                        PlayerSlot.slot4
                      ];
                    }

                    List<Widget> widgets = [];
                    for (int i = 0; i < displaySlots.length; i++) {
                      final slot = displaySlots[i];

                      if (isTeam && i == 0) {
                        widgets.add(_buildTeamHeader("TEAM A"));
                      } else if (isTeam && i == 2) {
                        widgets.add(_buildVsDivider());
                        widgets.add(_buildTeamHeader("TEAM B"));
                      }

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

                      widgets.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controllers[slot],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Player ${slot.index + 1}',
                                    labelStyle: TextStyle(color: displayColor),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: displayColor.withValues(
                                              alpha: 0.5)),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: displayColor, width: 2),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: (_isBotConfig[slot] ?? false)
                                          ? RobotIcon(
                                              size: 22, color: displayColor)
                                          : Icon(Icons.person,
                                              color: displayColor),
                                    ),
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
                                    activeThumbColor: displayColor,
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
                        ),
                      );
                    }
                    return widgets;
                  })(),
                  if (kDebugMode) ...[
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
                      initialValue: _initialState,
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
                  ],
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E4E2),
                      foregroundColor: const Color(0xFF1E1E2C),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor:
                          const Color(0xFFE5E4E2).withValues(alpha: 0.5),
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
                                      initialState: _initialState,
                                      gameMode: _gameMode)),
                            ],
                            child: const LudoScreen(),
                          ),
                        ),
                      );
                    },
                    child: const Text('Start Game',
                        style: TextStyle(
                            color: Color(0xFF1E1E2C),
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

  Widget _buildTeamHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: title.contains('A') ? Colors.blueAccent : Colors.redAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVsDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent.withValues(alpha: 0.8),
                  Colors.redAccent.withValues(alpha: 0.8)
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Text(
              'VS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        ],
      ),
    );
  }

  Widget _buildGameModeChip({
    required GameMode mode,
    required String label,
    required String description,
    required IconData icon,
    required bool isEnabled,
  }) {
    final isSelected = _gameMode == mode;
    final color = isSelected ? const Color(0xFFE5E4E2) : Colors.white70;

    return Tooltip(
      message: isEnabled ? '' : '2vs2 mode requires exactly 4 players',
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                setState(() {
                  _gameMode = mode;
                });
              }
            : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            width: 150,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE5E4E2)
                  : const Color(0xFF2A2A3D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.blueAccent.withValues(alpha: 0.5)
                    : Colors.white10,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF1E1E2C) : color,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF1E1E2C) : color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEnabled ? description : 'Locked',
                  style: TextStyle(
                    color: (isSelected ? const Color(0xFF1E1E2C) : color)
                        .withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
