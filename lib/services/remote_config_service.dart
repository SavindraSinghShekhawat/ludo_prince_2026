import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_logger.dart';

enum UpdateStatus { none, suggest, force }

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // Keys
  static const String _keyMinSupportedVersion = 'min_supported_version';
  static const String _keyLatestVersion = 'latest_version';
  static const String _keyForceUpdate = 'force_update';
  static const String _keyUpdateMessage = 'update_message';

  UpdateStatus _updateStatus = UpdateStatus.none;
  UpdateStatus get updateStatus => _updateStatus;

  String? _currentVersion;
  String get currentVersion => _currentVersion ?? '0.0.0';

  String get updateMessage => _remoteConfig.getString(_keyUpdateMessage);
  String get latestVersion => _remoteConfig.getString(_keyLatestVersion);

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );

      await _remoteConfig.setDefaults({
        _keyMinSupportedVersion: '1.0.1',
        _keyLatestVersion: '1.0.3',
        _keyForceUpdate: true,
        _keyUpdateMessage: 'Please update the app to continue',
      });

      await _remoteConfig.fetchAndActivate();

      AppLogger.debug(
        '[RemoteConfigService] Fetch Status: ${_remoteConfig.lastFetchStatus}',
      );
      AppLogger.debug(
        '[RemoteConfigService] Last Fetch Time: ${_remoteConfig.lastFetchTime}',
      );

      // Listen for real-time updates (requires firebase_remote_config 6.1.0+)
      _remoteConfig.onConfigUpdated.listen((event) async {
        AppLogger.debug(
          '[RemoteConfigService] Real-time config update detected: ${event.updatedKeys}',
        );
        await _remoteConfig.activate();
        await checkUpdate();
      });

      await checkUpdate();
    } catch (e) {
      AppLogger.error('[RemoteConfigService] Error initialization: $e');
    }
  }

  Future<UpdateStatus> checkUpdate() async {
    AppLogger.debug('[RemoteConfigService] Starting version check...');
    final packageInfo = await PackageInfo.fromPlatform();
    // Clean version string (remove everything after +)
    _currentVersion = packageInfo.version.split('+').first;
    final currentVersion = _currentVersion!;

    final minSupported = _remoteConfig.getString(_keyMinSupportedVersion);
    final remoteLatest = _remoteConfig.getString(_keyLatestVersion);
    final forceRequested = _remoteConfig.getBool(_keyForceUpdate);

    // Logic: Suggested Latest is max(local, remote)
    // We only suggest/force if remote is strictly higher than local
    AppLogger.debug(
      '[RemoteConfigService] Comparison -> Local: $currentVersion | Remote Min: $minSupported | Remote Latest: $remoteLatest | Force Flag: $forceRequested',
    );

    if (_isVersionLower(currentVersion, minSupported)) {
      AppLogger.debug(
        '[RemoteConfigService] Local version is BELOW minimum supported version',
      );
      _updateStatus =
          forceRequested ? UpdateStatus.force : UpdateStatus.suggest;
    } else if (_isVersionLower(currentVersion, remoteLatest)) {
      AppLogger.debug(
        '[RemoteConfigService] Local version is BELOW remote latest version',
      );
      _updateStatus = UpdateStatus.suggest;
    } else {
      AppLogger.debug(
        '[RemoteConfigService] App is up to date or newer than remote',
      );
      _updateStatus = UpdateStatus.none;
    }

    AppLogger.info('[RemoteConfigService] Update Check Result: $_updateStatus');
    return _updateStatus;
  }

  bool _isVersionLower(String current, String target) {
    AppLogger.debug('[RemoteConfigService] Comparing $current vs $target');
    try {
      // Clean target just in case
      final cleanTarget = target.split('+').first;

      final currentParts =
          current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final targetParts =
          cleanTarget.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (var i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final t = i < targetParts.length ? targetParts[i] : 0;
        if (c < t) return true;
        if (c > t) return false;
      }
    } catch (e) {
      AppLogger.error('[RemoteConfigService] Version parsing error: $e');
    }
    return false;
  }
}

final remoteConfigService = RemoteConfigService();
