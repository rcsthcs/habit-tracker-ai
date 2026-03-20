import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class PushNotificationService {
  static bool _isInitialized = false;

  static String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  static Future<void> setupAndRegisterToken(ApiService api) async {
    if (kIsWeb) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      if (!_isInitialized) {
        FirebaseMessaging.onTokenRefresh.listen((token) async {
          if (token.isEmpty) return;
          try {
            await api.registerDeviceToken(token, platform: _platform);
          } catch (_) {}
        });
        _isInitialized = true;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await api.registerDeviceToken(token, platform: _platform);
    } catch (e) {
      debugPrint('Push setup skipped: $e');
    }
  }
}
