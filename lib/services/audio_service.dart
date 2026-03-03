import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  AudioService._internal();

  final AudioPlayer _rollPlayer = AudioPlayer();
  final AudioPlayer _sixPlayer = AudioPlayer();
  final AudioPlayer _movePlayer = AudioPlayer();
  final AudioPlayer _diePlayer = AudioPlayer();
  final AudioPlayer _homePlayer = AudioPlayer();
  final AudioPlayer _safePlayer = AudioPlayer();
  final AudioPlayer _startPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _victoryPlayer = AudioPlayer();

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

    final players = [
      _rollPlayer,
      _sixPlayer,
      _movePlayer,
      _diePlayer,
      _homePlayer,
      _safePlayer,
      _startPlayer,
      _victoryPlayer,
    ];

    for (final p in players) {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
    }

    await _movePlayer.setVolume(0.5);
    await _rollPlayer.setVolume(0.8);
    await _bgmPlayer.setVolume(0.55);
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);

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
    if (_bgmPlayer.state != PlayerState.playing) {
      await _bgmPlayer.play(AssetSource('sounds/bgm.wav'));
    }
  }

  Future<void> stopBGM() async {
    await _bgmPlayer.stop();
  }

  Future<void> pauseBGM() async {
    if (_bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.pause();
    }
  }

  Future<void> resumeBGM() async {
    await init();
    if (!_isBgmEnabled) return;
    if (_bgmPlayer.state == PlayerState.paused) {
      await _bgmPlayer.resume();
    }
  }

  Future<void> playRoll() async {
    await init();
    if (!_isSfxEnabled) return;
    await _rollPlayer.play(AssetSource('sounds/roll.wav'));
  }

  Future<void> playSix() async {
    await init();
    if (!_isSfxEnabled) return;
    await _sixPlayer.play(AssetSource('sounds/six.wav'));
  }

  Future<void> playMove(int steps) async {
    await init();
    if (!_isSfxEnabled) return;
    final safeSteps = steps.clamp(1, 6);
    await _movePlayer.play(AssetSource('sounds/move_$safeSteps.wav'));
  }

  Future<void> playDie() async {
    await init();
    if (!_isSfxEnabled) return;
    await _diePlayer.play(AssetSource('sounds/die.wav'));
  }

  Future<void> playHome() async {
    await init();
    if (!_isSfxEnabled) return;
    await _homePlayer.play(AssetSource('sounds/home.wav'));
  }

  Future<void> playSafe() async {
    await init();
    if (!_isSfxEnabled) return;
    await _safePlayer.play(AssetSource('sounds/safe.wav'));
  }

  Future<void> playStart() async {
    await init();
    if (!_isSfxEnabled) return;
    await _startPlayer.play(AssetSource('sounds/start.wav'));
  }

  Future<void> playVictory() async {
    await init();
    if (!_isSfxEnabled) return;
    await _victoryPlayer.play(AssetSource('sounds/victory.wav'));
  }
}

final audioService = AudioService();
