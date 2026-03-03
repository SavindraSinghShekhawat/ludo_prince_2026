import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';

final audioProvider = ChangeNotifierProvider<AudioService>((ref) {
  return audioService;
});
