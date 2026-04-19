import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();

  static Future<bool> hasInternet() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Stream<bool> get connectivityStream async* {
    // Yield the initial state immediately
    yield await hasInternet();

    // Then yield all future changes
    yield* _connectivity.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }
}

final networkService = NetworkService();
