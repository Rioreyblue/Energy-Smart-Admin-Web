import 'package:flutter_dotenv/flutter_dotenv.dart';

class OneSignalConfig {
  static const String _defaultAppId = '741790af-bbf1-4480-9c92-18352b884ea3';
  static const String _defaultRestApiKey =
      'os_v2_app_oqlzbl536fcibhesda2sxccouofuzizc5whee654wflfcmhutyywvfb3jwye34sqh4phvqhuqcgq2jwhnlidd5ax2oqsxrwljxted7q';
  static const String _defaultApiUrl =
      'https://api.onesignal.com/v1/notifications';

  static String get appId => _read('ONESIGNAL_APP_ID') ?? _defaultAppId;

  static String get restApiKey =>
      _read('ONESIGNAL_REST_API_KEY') ?? _defaultRestApiKey;

  static String get apiUrl => _read('ONESIGNAL_API_URL') ?? _defaultApiUrl;

  static String get androidSmallIcon =>
      _read('ONESIGNAL_ANDROID_SMALL_ICON') ?? 'ic_notification';

  static String? get notificationIconUrl => _read('NOTIFICATION_ICON_URL');

  static String? _read(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
