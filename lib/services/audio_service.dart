import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  AudioService._internal();

  bool _initialized = false;
  bool _isBgmEnabled = true;
  bool _isSfxEnabled = true;
  bool _isVibrationEnabled = true;
  AudioPlayer? _rollLoopPlayer;
  bool _shouldBeLoopingRoll = false;

  /// Pool of active SFX players, keyed by filename.
  /// Ensures at most one AudioPlayer per sound file exists at any time,
  /// preventing the unbounded memory growth from FlameAudio.play().
  final Map<String, AudioPlayer> _sfxPlayers = {};

  bool get isBgmEnabled => _isBgmEnabled;
  bool get isSfxEnabled => _isSfxEnabled;
  bool get isVibrationEnabled => _isVibrationEnabled;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isBgmEnabled = prefs.getBool('bgm_enabled') ?? true;
    _isSfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    _isVibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    _initialized = true;
    notifyListeners();
  }

  /// Plays a SFX file using a pooled AudioPlayer.
  /// Disposes the previous player for the same file before creating a new one,
  /// keeping the total player count bounded to ~12 (one per unique sound).
  Future<void> _playSfx(String file, {double volume = 0.8}) async {
    await init();
    if (!_isSfxEnabled) return;

    // Dispose previous player for this sound to free native resources
    final old = _sfxPlayers.remove(file);
    if (old != null) {
      try {
        old.dispose();
      } catch (_) {
        // Player may already be disposed
      }
    }

    try {
      _sfxPlayers[file] = await FlameAudio.play(file, volume: volume);
    } catch (e) {
      debugPrint('AudioService: Failed to play $file: $e');
    }
  }

  /// Releases all pooled SFX players. Call when the game ends or the app
  /// goes to background to free native audio resources immediately.
  void disposeAllSfx() {
    for (final player in _sfxPlayers.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _sfxPlayers.clear();
  }

  Future<void> toggleBGM() async {
    await init();
    _isBgmEnabled = !_isBgmEnabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bgm_enabled', _isBgmEnabled);

    notifyListeners();

    if (_isBgmEnabled) {
      await playBGM();
    } else {
      await stopBGM();
    }
  }

  Future<void> toggleSFX() async {
    await init();
    _isSfxEnabled = !_isSfxEnabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sfx_enabled', _isSfxEnabled);

    notifyListeners();
  }

  Future<void> toggleVibration() async {
    await init();
    _isVibrationEnabled = !_isVibrationEnabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', _isVibrationEnabled);

    notifyListeners();
    if (_isVibrationEnabled) {
      await playVibrate();
    }
  }

  Future<void> playBGM() async {
    await init();
    if (!_isBgmEnabled) return;

    FlameAudio.bgm.play('bgm.wav', volume: 0.55);
  }

  Future<void> stopBGM() async {
    FlameAudio.bgm.stop();
  }

  Future<void> pauseBGM() async {
    FlameAudio.bgm.pause();
  }

  Future<void> resumeBGM() async {
    await init();
    if (!_isBgmEnabled) return;

    FlameAudio.bgm.resume();
  }

  Future<void> playRoll() async {
    await _playSfx('roll.wav', volume: 0.8);
  }

  Future<void> startRollLoop() async {
    _shouldBeLoopingRoll = true;
    await init();
    if (!_isSfxEnabled || !_shouldBeLoopingRoll || _rollLoopPlayer != null) {
      return;
    }
    _rollLoopPlayer = await FlameAudio.loop('roll_loop.wav', volume: 0.7);
  }

  void stopRollLoop() {
    _shouldBeLoopingRoll = false;
    _rollLoopPlayer?.stop();
    _rollLoopPlayer = null;
  }

  Future<void> playSix() async {
    await _playSfx('six.wav', volume: 0.8);
  }

  Future<void> playMove(int steps) async {
    final safeSteps = steps.clamp(1, 6);
    await _playSfx('move_$safeSteps.wav', volume: 0.5);
  }

  Future<void> playDie() async {
    await _playSfx('die.wav', volume: 0.8);
  }

  Future<void> playHome() async {
    await _playSfx('home.wav', volume: 0.8);
  }

  Future<void> playSafe() async {
    await _playSfx('safe.wav', volume: 0.8);
  }

  Future<void> playStart() async {
    await _playSfx('start.wav', volume: 0.8);
  }

  Future<void> playVictory() async {
    await _playSfx('victory.wav', volume: 0.8);
  }

  Future<void> playVibrate() async {
    await init();
    if (!_isVibrationEnabled) return;

    // Use HapticFeedback for vibration
    await HapticFeedback.mediumImpact();
  }
}

final audioService = AudioService();
