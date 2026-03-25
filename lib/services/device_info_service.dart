import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final Map<String, dynamic> info = {};
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      info['appVersion'] = packageInfo.version;
      info['buildNumber'] = packageInfo.buildNumber;
      info['packageName'] = packageInfo.packageName;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info.addAll({
          'platform': 'Android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info.addAll({
          'platform': 'iOS',
          'model': iosInfo.utsname.machine,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        });
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        info.addAll({
          'platform': 'macOS',
          'model': macInfo.model,
          'osRelease': macInfo.osRelease,
          'arch': macInfo.arch,
          'memorySize': macInfo.memorySize,
        });
      } else {
        info['platform'] = Platform.operatingSystem;
      }
    } catch (e) {
      info['error'] = e.toString();
    }
    return info;
  }

  Future<String> getDeviceInfoSummary() async {
    final info = await getDeviceInfo();
    if (info.containsKey('error')) return 'Error fetching device info';

    final platform = info['platform'];
    final appVersion = info['appVersion'] ?? 'unknown';
    final buildNumber = info['buildNumber'] ?? 'unknown';
    final versionStr = 'v$appVersion+$buildNumber';

    if (platform == 'Android') {
      return '[$versionStr] $platform ${info['version']} - ${info['brand']} ${info['model']}';
    } else if (platform == 'iOS') {
      return '[$versionStr] $platform ${info['systemVersion']} - ${info['model']}';
    } else if (platform == 'macOS') {
      return '[$versionStr] $platform ${info['osRelease']} - ${info['model']}';
    }
    return '[$versionStr] ${platform ?? 'Unknown Platform'}';
  }
}

final deviceInfoServiceProvider = Provider((ref) => DeviceInfoService());

final deviceMetadataProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(deviceInfoServiceProvider).getDeviceInfo();
});

final deviceSummaryProvider = FutureProvider<String>((ref) async {
  return ref.watch(deviceInfoServiceProvider).getDeviceInfoSummary();
});
