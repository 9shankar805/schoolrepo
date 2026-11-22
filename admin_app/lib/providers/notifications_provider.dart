import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> notifications = [];
  int unreadCount = 0;
  bool isLoading = false;
  String? error;

  // ---------------------------------------------------------------------------
  // Fetching
  // ---------------------------------------------------------------------------

  Future<void> fetchNotifications({String type = 'all'}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final res = await _api.getNotifications(type: type != 'all' ? type : null);

    isLoading = false;

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      notifications = (data['data'] as List<dynamic>?) ?? [];
      unreadCount = (data['unread_count'] as int?) ?? 0;
    } else {
      error = res.message;
    }

    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    final count = await _api.getUnreadNotificationCount();
    unreadCount = count;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> markRead(String id) async {
    final res = await _api.markNotificationRead(id);
    if (res.success) {
      final idx = notifications.indexWhere((n) => n['id'].toString() == id);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(notifications[idx] as Map);
        updated['read_at'] = DateTime.now().toIso8601String();
        notifications[idx] = updated;
        if (unreadCount > 0) unreadCount--;
        notifyListeners();
      }
    }
  }

  Future<bool> markAllRead() async {
    final res = await _api.markAllNotificationsRead();
    if (res.success) {
      notifications = notifications.map((n) {
        final m = Map<String, dynamic>.from(n as Map);
        m['read_at'] ??= DateTime.now().toIso8601String();
        return m;
      }).toList();
      unreadCount = 0;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteNotification(String id) async {
    final res = await _api.deleteNotification(id);
    if (res.success) {
      final wasUnread = notifications.any(
        (n) => n['id'].toString() == id && n['read_at'] == null,
      );
      notifications.removeWhere((n) => n['id'].toString() == id);
      if (wasUnread && unreadCount > 0) unreadCount--;
      notifyListeners();
      return true;
    }
    return false;
  }
}
