import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// A single notification item — may come from FCM (live) or the backend (history).
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final String? orderId;
  final NotificationType type;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.orderId,
    required this.type,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['notif_id'] as String? ?? j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['created_at'] as num?)?.toInt() ?? 0,
      ),
      orderId: j['order_id'] as String?,
      type: _typeFromString(j['type'] as String? ?? ''),
      isRead: j['is_read'] as bool? ?? false,
    );
  }
}

enum NotificationType {
  orderAccepted,
  outForDelivery,
  delivered,
  orderFailed,
  broadcasting,
  announcement,
  offer,
  system,
  general,
}

NotificationType _typeFromString(String t) {
  switch (t) {
    case 'order_accepted':
      return NotificationType.orderAccepted;
    case 'out_for_delivery':
      return NotificationType.outForDelivery;
    case 'order_delivered':
    case 'delivered':
      return NotificationType.delivered;
    case 'order_failed':
      return NotificationType.orderFailed;
    case 'broadcasting':
      return NotificationType.broadcasting;
    case 'announcement':
      return NotificationType.announcement;
    case 'offer':
      return NotificationType.offer;
    case 'system':
      return NotificationType.system;
    default:
      return NotificationType.general;
  }
}

/// Manages notification history for the customer app.
///
/// On app start, call [loadFromBackend] to hydrate from persisted history.
/// FCM messages are added live via [add]. Deduplication prevents duplicates
/// when a notification was saved to the backend AND received via FCM.
class NotificationProvider extends ChangeNotifier {
  // Map from notif_id → AppNotification for O(1) dedup.
  final Map<String, AppNotification> _byId = {};

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  /// Sorted newest-first.
  List<AppNotification> get notifications {
    final list = _byId.values.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return list;
  }

  int get unreadCount => _byId.values.where((n) => !n.isRead).length;

  /// Loads notification history from the backend GET /notifications/me.
  Future<void> loadFromBackend() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await ApiClient.get('/notifications/me');
      if (resp.statusCode == 200) {
        final data = ApiClient.parseBody(resp);
        final List<dynamic> items = data is List
            ? data
            : (data is Map ? (data['notifications'] as List? ?? []) : []);
        for (final item in items) {
          final n = AppNotification.fromJson(item as Map<String, dynamic>);
          _byId[n.id] = n;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Adds a live FCM notification (deduplicates by id).
  void add({
    required String title,
    required String body,
    String? orderId,
    NotificationType type = NotificationType.general,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _byId[id] = AppNotification(
      id: id,
      title: title,
      body: body,
      receivedAt: DateTime.now(),
      orderId: orderId,
      type: type,
    );
    notifyListeners();
  }

  /// Marks a single notification as read via PATCH /notifications/{id}/read.
  Future<void> markRead(String id) async {
    final n = _byId[id];
    if (n == null || n.isRead) return;
    n.isRead = true;
    notifyListeners();
    try {
      await ApiClient.patch('/notifications/$id/read', {});
    } catch (_) {
      // Best-effort; local state already updated
    }
  }

  /// Marks all notifications as read via PATCH /notifications/me/read-all.
  Future<void> markAllRead() async {
    for (final n in _byId.values) {
      n.isRead = true;
    }
    notifyListeners();
    try {
      await ApiClient.patch('/notifications/me/read-all', {});
    } catch (_) {}
  }

  /// Deletes all notifications via DELETE /notifications/me.
  Future<void> clearAll() async {
    _byId.clear();
    notifyListeners();
    try {
      await ApiClient.delete('/notifications/me');
    } catch (_) {}
  }

  /// Helper used by FcmService to map FCM data payload to a NotificationType.
  static NotificationType typeFromData(Map<String, dynamic> data) {
    return _typeFromString(data['type'] as String? ?? '');
  }
}
