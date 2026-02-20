import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../core/config.dart';

/// Notification service — polls backend for notifications.
/// In production, replace with Firebase Cloud Messaging.
class NotificationService {
  final ApiService _api;
  Timer? _pollTimer;

  NotificationService(this._api);

  void startPolling({Function(List<Map<String, dynamic>>)? onNotifications}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConfig.notificationPollIntervalSeconds),
      (_) async {
        try {
          final notifications = await _api.getNotifications();
          if (notifications.isNotEmpty && onNotifications != null) {
            onNotifications(notifications);
          }
        } catch (e) {
          debugPrint('Notification poll error: $e');
        }
      },
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

