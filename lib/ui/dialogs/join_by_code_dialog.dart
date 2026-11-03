import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/services/matchmaking_service.dart';
import 'package:ludo_prince/services/audio_service.dart';
import '../widgets/shared_ui.dart';
import '../screens/lobby_screen.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';

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
  void initState() {
    super.initState();
    for (var node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

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
    final cleanDigits = value.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length > 1) {
      for (int i = 0; i < cleanDigits.length && (index + i) < 6; i++) {
        _controllers[index + i].text = cleanDigits[i];
      }
      final nextIndex = (index + cleanDigits.length).clamp(0, 5);
      _focusNodes[nextIndex].requestFocus();
      setState(() {});
      if (_controllers.every((c) => c.text.isNotEmpty)) {
        _submit();
      }
      return;
    }

    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    setState(() {});
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _submit();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null) return;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    for (int i = 0; i < 6 && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    final nextFocus = (digits.length < 6 ? digits.length : 5);
    _focusNodes[nextFocus].requestFocus();
    setState(() {});
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
        await audioService.playDie();
        return;
      }

      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      Navigator.push(
        context,
        ScaleFadePageRoute(
          page: LobbyScreen(
            initialGameId: gameId,
            isHost: false,
            isQuickMatch: false,
          ),
          settings: const RouteSettings(name: '/lobby'),
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
    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: GlassContainer(
            padding: const EdgeInsets.all(28),
            borderRadius: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryCyan.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppColors.primaryCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    color: AppColors.primaryCyan,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ENTER ROOM CODE',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter the 6-digit room code to join',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // High-Contrast Digit Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    final isFocused = _focusNodes[index].hasFocus;
                    final hasValue = _controllers[index].text.isNotEmpty;

                    return Container(
                      width: 46,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141926),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused
                              ? AppColors.primaryCyan
                              : hasValue
                                  ? AppColors.starPlatinum
                                  : Colors.white.withValues(alpha: 0.22),
                          width: isFocused ? 2.0 : 1.5,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryCyan
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        onChanged: (v) => _onChanged(v, index),
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: TextInputType.number,
                        cursorColor: AppColors.primaryCyan,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),
                // Quick Paste button
                InkWell(
                  onTap: _pasteFromClipboard,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.paste_rounded,
                          size: 14,
                          color: AppColors.primaryCyan,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'PASTE CODE',
                          style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                if (_isLoading)
                  const AppLoadingDots(size: 30)
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AppButton(
                          text: 'JOIN',
                          color: AppColors.starPlatinum,
                          onTap: _submit,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
