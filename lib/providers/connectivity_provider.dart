import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/services/network_service.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  return networkService.connectivityStream;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).value ?? true;
});
