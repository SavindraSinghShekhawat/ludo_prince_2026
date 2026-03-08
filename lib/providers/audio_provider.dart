import 'package:flutter_riverpod/legacy.dart';
import '../services/audio_service.dart';

final audioProvider = ChangeNotifierProvider<AudioService>((ref) {
  return audioService;
});
