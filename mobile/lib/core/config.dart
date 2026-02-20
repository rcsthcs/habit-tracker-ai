/// App configuration — change baseUrl for production deployment.
class AppConfig {
  // Local dev: Android emulator uses 10.0.2.2, iOS simulator uses localhost
  // Web uses localhost directly
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  static const String baseUrlWeb = 'http://localhost:8000/api';

  // Production: replace with your server URL
  // static const String baseUrl = 'https://your-server.com/api';

  static const String appName = 'Habit Tracker AI';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration chatTimeout = Duration(seconds: 60);
  static const int notificationPollIntervalSeconds = 60;
}

