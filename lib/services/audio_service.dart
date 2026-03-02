import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal() {
    _init();
  }

  final AudioPlayer _rollPlayer = AudioPlayer();
  final AudioPlayer _sixPlayer = AudioPlayer();
  final AudioPlayer _movePlayer = AudioPlayer();
  final AudioPlayer _diePlayer = AudioPlayer();
  final AudioPlayer _homePlayer = AudioPlayer();
  final AudioPlayer _safePlayer = AudioPlayer();
  final AudioPlayer _startPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  void _init() {
    _rollPlayer.setReleaseMode(ReleaseMode.stop);
    _sixPlayer.setReleaseMode(ReleaseMode.stop);
    _movePlayer.setReleaseMode(ReleaseMode.stop);
    _diePlayer.setReleaseMode(ReleaseMode.stop);
    _homePlayer.setReleaseMode(ReleaseMode.stop);
    _safePlayer.setReleaseMode(ReleaseMode.stop);
    _startPlayer.setReleaseMode(ReleaseMode.stop);
    
    // Low latency mode is important for game sound effects
    _rollPlayer.setPlayerMode(PlayerMode.lowLatency);
    _sixPlayer.setPlayerMode(PlayerMode.lowLatency);
    _movePlayer.setPlayerMode(PlayerMode.lowLatency);
    _diePlayer.setPlayerMode(PlayerMode.lowLatency);
    _homePlayer.setPlayerMode(PlayerMode.lowLatency);
    _safePlayer.setPlayerMode(PlayerMode.lowLatency);
    _startPlayer.setPlayerMode(PlayerMode.lowLatency);

    // Fine tune volume
    _movePlayer.setVolume(0.5);
    _rollPlayer.setVolume(0.8);
    _bgmPlayer.setVolume(0.55); // Increased background music volume
    
    // Set BGM to loop indefinitely
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> playBGM() async {
    // We only want to start the BGM if it isn't already playing.
    if (_bgmPlayer.state != PlayerState.playing) {
      await _bgmPlayer.play(AssetSource('sounds/bgm.wav'));
    }
  }

  void stopBGM() {
    _bgmPlayer.stop();
  }

  Future<void> playRoll() async {
    await _rollPlayer.play(AssetSource('sounds/roll.wav'));
  }

  Future<void> playSix() async {
    await _sixPlayer.play(AssetSource('sounds/six.wav'));
  }

  Future<void> playMove(int steps) async {
    // clamp steps between 1 and 6
    int safeSteps = steps.clamp(1, 6);
    await _movePlayer.play(AssetSource('sounds/move_$safeSteps.wav'));
  }

  Future<void> playDie() async {
    await _diePlayer.play(AssetSource('sounds/die.wav'));
  }

  Future<void> playHome() async {
    await _homePlayer.play(AssetSource('sounds/home.wav'));
  }

  Future<void> playSafe() async {
    await _safePlayer.play(AssetSource('sounds/safe.wav'));
  }

  Future<void> playStart() async {
    await _startPlayer.play(AssetSource('sounds/start.wav'));
  }
}

// Global instance getter for easy use
final audioService = AudioService();
