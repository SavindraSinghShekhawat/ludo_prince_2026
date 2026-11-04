import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
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
    if (_isLoading) return;
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
    if (_isLoading) return;
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
    if (_isLoading) return;
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    FocusScope.of(context).unfocus();

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
      child: PopScope(
        canPop: !_isLoading,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassContainer(
              padding: const EdgeInsets.all(32),
              borderRadius: 30,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.vpn_key,
                    color: Colors.amberAccent,
                    size: 48,
                  ),
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
                  const SizedBox(height: 28),

                  // Clean Underline Digit Slots (not editable when finding room)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      final hasValue = _controllers[index].text.isNotEmpty;

                      return SizedBox(
                        width: 44,
                        child: TextField(
                          autofocus: index == 0,
                          enabled: !_isLoading,
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          onChanged: (v) => _onChanged(v, index),
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          cursorColor: Colors.amberAccent,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          style: TextStyle(
                            color: _isLoading ? Colors.white60 : Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: hasValue
                                    ? Colors.amberAccent
                                    : Colors.white.withValues(alpha: 0.35),
                                width: 2.0,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.amberAccent,
                                width: 2.5,
                              ),
                            ),
                            disabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: hasValue
                                    ? Colors.amberAccent.withValues(alpha: 0.5)
                                    : Colors.white24,
                                width: 2.0,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),
                  // Quick Paste button in amber theme
                  Opacity(
                    opacity: _isLoading ? 0.35 : 1.0,
                    child: InkWell(
                      onTap: _isLoading ? null : _pasteFromClipboard,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.paste_rounded,
                              size: 14,
                              color: Colors.amberAccent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'PASTE CODE',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 28),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: AppLoadingDots(size: 32)),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'JOIN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
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
