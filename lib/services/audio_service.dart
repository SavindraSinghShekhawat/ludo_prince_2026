import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  AudioService._internal();

  bool _initialized = false;
  bool _isBgmEnabled = true;
  bool _isSfxEnabled = true;

  bool get isBgmEnabled => _isBgmEnabled;
  bool get isSfxEnabled => _isSfxEnabled;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isBgmEnabled = prefs.getBool('bgm_enabled') ?? true;
    _isSfxEnabled = prefs.getBool('sfx_enabled') ?? true;

    _initialized = true;
    notifyListeners();
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

  Future<void> playBGM() async {
    await init();
    if (!_isBgmEnabled) return;

    FlameAudio.bgm.play(
      'bgm.wav',
      volume: 0.55,
    );
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
    await init();
    if (!_isSfxEnabled) return;

    FlameAudio.play('roll.wav', volume: 0.8);
  }

  Future<void> playSix() async {
    await init();
    if (!_isSfxEnabled) return;

    FlameAudio.play('six.wav', volume: 0.8);
  }

  Future<void> playMove(int steps) async {
    await init();
    if (!_isSfxEnabled) return;

    final safeSteps = steps.clamp(1, 6);
    FlameAudio.play('move_$safeSteps.wav', volume: 0.5);
  }

  Future<void> playDie() async {
    await init();
    if (!_isSfxEnabled) return;

    FlameAudio.play('die.wav', volume: 0.8);
  }

  Future<void> playHome() async {
    await init();
    if (!_isSfxEnabled) return;

    FlameAudio.play('home.wav', volume: 0.8);
  }

  Future<void> playSafe() async {
    await init();
    if (!_isSfxEnabled) return;

    FlameAudio.play('safe.wav', volume: 0.8);
  }

  Future<void> playStart() async {
    await init();
    if (!_isSfxEnabled) return;

    FlameAudio.play('start.wav', volume: 0.8);
  }

  Future<void> playVictory() async {
    await init();
    if (!_isSfxEnabled) return;

    FlameAudio.play('victory.wav', volume: 0.8);
  }
}

final audioService = AudioService();
