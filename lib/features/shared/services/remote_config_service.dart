import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  static const String _googleMapsApiKey = 'GOOGLE_MAPS_API_KEY';
  static const String _fallbackApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: 'AIzaSyDp17RxIsSydQqKZGBRsYtJkmGdwqnHZ84');

  static Future<FirebaseRemoteConfig?> get instance async {
    try {
      _remoteConfig ??= FirebaseRemoteConfig.instance;
      
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await _remoteConfig!.setDefaults({
        _googleMapsApiKey: _fallbackApiKey,
      });

      await _remoteConfig!.fetchAndActivate();
      return _remoteConfig!;
    } catch (e) {
      return null;
    }
  }

  static Future<String> getGoogleMapsApiKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString(_googleMapsApiKey);
        return key.isNotEmpty ? key : _fallbackApiKey;
      }
      return _fallbackApiKey;
    } catch (e) {
      return _fallbackApiKey;
    }
  }
}