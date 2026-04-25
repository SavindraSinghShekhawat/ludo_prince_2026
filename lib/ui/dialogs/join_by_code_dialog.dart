import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ludo_prince/services/matchmaking_service.dart';
import 'package:ludo_prince/services/audio_service.dart';
import '../widgets/shared_ui.dart';
import '../screens/lobby_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class JoinByCodeDialog extends StatefulWidget {
  const JoinByCodeDialog({super.key});

  @override
  State<JoinByCodeDialog> createState() => _JoinByCodeDialogState();
}

class _JoinByCodeDialogState extends State<JoinByCodeDialog> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _submit();
    }
  }

  Future<void> _submit() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gameId = await matchmakingService.getGameIdFromCode(code);
      if (gameId == null) {
        setState(() {
          _isLoading = false;
          _error = "Invalid or expired room code.";
        });
        await audioService.playDie(); // Use playDie as fallback for error sound
        return;
      }

      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            initialGameId: gameId,
            isHost: false,
            isQuickMatch: false,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Failed to join: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key, color: Colors.amberAccent, size: 48)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(duration: 2.seconds),
            const SizedBox(height: 24),
            const Text(
              'ENTER ROOM CODE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your friend for the 6-digit code',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 40,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    onChanged: (v) => _onChanged(v, index),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.amberAccent),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.amberAccent)
            else
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'JOIN',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
