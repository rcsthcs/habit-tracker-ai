/// App configuration — change baseUrl for production deployment.
class AppConfig {
  // Google OAuth Web Client ID (required for backend Google token verification)
  static const String googleServerClientId = 'your-google-web-client-id.apps.googleusercontent.com';

  // Production server
  static const String baseUrl = 'https://rcsthcs.click/api';
  static const String baseUrlWeb = 'https://rcsthcs.click/api';

  /// Base server URL WITHOUT /api — used for static assets like avatars.
  static const String serverUrl = 'https://rcsthcs.click';
  static const String serverUrlWeb = 'https://rcsthcs.click';

  // Local dev (physical device on same WiFi):
  // static const String baseUrl = 'http://192.168.1.142:8000/api';
  // static const String baseUrlWeb = 'http://192.168.1.142:8000/api';
  // static const String serverUrl = 'http://192.168.1.142:8000';
  // static const String serverUrlWeb = 'http://192.168.1.142:8000';

  static const String appName = 'Habit Tracker AI';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration chatTimeout = Duration(seconds: 120);
  static const int notificationPollIntervalSeconds = 60;

  /// Convert a potentially relative avatar URL to a full URL.
  static String? fullAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return avatarUrl; // Already absolute (e.g., Google avatar)
    }
    return '$serverUrl$avatarUrl';
  }
}
