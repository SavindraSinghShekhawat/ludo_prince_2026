import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static Future<bool> hasInternet() async {
    final results = await Connectivity().checkConnectivity();

    return results.any((r) => r != ConnectivityResult.none);
  }
}

final networkService = NetworkService();
