import 'package:flutter_riverpod/legacy.dart';
import 'package:ludo_prince/services/audio_service.dart';

final audioProvider = ChangeNotifierProvider<AudioService>((ref) {
  return audioService;
});
