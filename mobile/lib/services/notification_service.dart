import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../core/config.dart';
import '../models/notification_item.dart';

/// Notification service — polls backend for unread notifications.
class NotificationService {
  final ApiService _api;
  Timer? _pollTimer;

  NotificationService(this._api);

  void startPolling({Function(List<NotificationItem>)? onNotifications}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConfig.notificationPollIntervalSeconds),
      (_) async {
        try {
          final notifications = await _api.getNotifications(unreadOnly: true);
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
