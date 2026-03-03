import 'package:audioplayers/audioplayers.dart';

class AudioService {
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

  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;

    final players = [
      _rollPlayer,
      _sixPlayer,
      _movePlayer,
      _diePlayer,
      _homePlayer,
      _safePlayer,
      _startPlayer,
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
  }

  Future<void> playBGM() async {
    await _init();
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
    if (_bgmPlayer.state == PlayerState.paused) {
      await _bgmPlayer.resume();
    }
  }


  Future<void> playRoll() async {
    await _init();
    await _rollPlayer.play(AssetSource('sounds/roll.wav'));
  }

  Future<void> playSix() async {
    await _init();
    await _sixPlayer.play(AssetSource('sounds/six.wav'));
  }

  Future<void> playMove(int steps) async {
    await _init();
    final safeSteps = steps.clamp(1, 6);
    await _movePlayer.play(AssetSource('sounds/move_$safeSteps.wav'));
  }

  Future<void> playDie() async {
    await _init();
    await _diePlayer.play(AssetSource('sounds/die.wav'));
  }

  Future<void> playHome() async {
    await _init();
    await _homePlayer.play(AssetSource('sounds/home.wav'));
  }

  Future<void> playSafe() async {
    await _init();
    await _safePlayer.play(AssetSource('sounds/safe.wav'));
  }

  Future<void> playStart() async {
    await _init();
    await _startPlayer.play(AssetSource('sounds/start.wav'));
  }
}

final audioService = AudioService();
