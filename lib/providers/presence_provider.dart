import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/presence_service.dart';

final onlineCountProvider = StreamProvider<int>((ref) {
  return presenceService.getOnlineCount();
});
