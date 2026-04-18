import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/ui/widgets/custom_dialog_layout.dart';
import 'package:ludo_prince/ui/widgets/robot_icon.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/utils/test_initialization.dart';
import 'ludo_screen.dart';
import '../../utils/colors.dart';
import '../dialogs/rules_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../../models/game_state.dart';
import '../../controllers/ludo_controller.dart';
import '../../models/token.dart';
import '../widgets/player_count_selector.dart';
import '../widgets/game_mode_selector.dart';
import '../widgets/shared_ui.dart';

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
    return PlayerSlotExtension.getSlotsFor(numPlayers);
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

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('OFFLINE'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                CustomDialogLayout.show(
                  context: context,
                  child: const RulesDialog(),
                );
              },
              tooltip: 'Game Rules',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                CustomDialogLayout.show(
                  context: context,
                  child: const SettingsDialog(),
                );
              },
              tooltip: 'Settings',
            ),
          ],
          centerTitle: true,
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).orientation == Orientation.landscape
                  ? 800
                  : double.infinity,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'SELECT NUMBER OF PLAYERS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          PlayerCountSelector(
                            currentCount: _numPlayers,
                            onCountChanged: (n) {
                              setState(() {
                                _numPlayers = n;
                                // Force Classic mode if players < 4
                                if (_numPlayers < 4) {
                                  _gameMode = GameMode.classic;
                                }
                                _initControllers();
                              });
                            },
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'SELECT GAME MODE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          GameModeSelector(
                            currentMode: _gameMode,
                            isTeamModeEnabled: _numPlayers == 4,
                            onModeChanged: (mode) {
                              setState(() {
                                _gameMode = mode;
                              });
                            },
                          ),
                          const SizedBox(height: 40),
                          const Text(
                            'PLAYER NAMES',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ...(() {
                            List<PlayerSlot> displaySlots = List.from(
                              activeSlots,
                            );
                            bool isTeam =
                                _gameMode == GameMode.team && _numPlayers == 4;

                            if (isTeam) {
                              displaySlots = [
                                PlayerSlot.slot1,
                                PlayerSlot.slot3,
                                PlayerSlot.slot2,
                                PlayerSlot.slot4,
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

                              Color displayColor = AppColors.getUiColorForSlot(
                                slot,
                              );

                              widgets.add(
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _controllers[slot],
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Player Name',
                                            labelStyle: TextStyle(
                                              color: displayColor,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: displayColor.withValues(
                                                  alpha: 0.5,
                                                ),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: displayColor,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child:
                                                  (_isBotConfig[slot] ?? false)
                                                  ? RobotIcon(
                                                      size: 22,
                                                      color: displayColor,
                                                    )
                                                  : Icon(
                                                      Icons.person,
                                                      color: displayColor,
                                                    ),
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFF2A2A3D),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        children: [
                                          const Text(
                                            'Bot',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
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
                              'INITIAL GAME STATE (TESTING)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
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
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: GameButton(
                    text: 'START GAME',
                    isPrimary: true,
                    fontSize: 18,
                    onTap: () async {
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
                                LudoController(
                                  config,
                                  initialState: _initialState,
                                  gameMode: _gameMode,
                                ),
                              ),
                            ],
                            child: const LudoScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
              color: title.contains('A')
                  ? AppColors.player1BlueUI
                  : AppColors.player4RedUI,
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
                  Colors.redAccent.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.player1BlueUI.withValues(alpha: 0.3),
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
}
