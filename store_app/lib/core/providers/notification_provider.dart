import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// A single notification — may come from FCM (live) or the backend (history).
class StoreNotification {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final String? orderId;
  final StoreNotificationType type;
  bool isRead;

  StoreNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.orderId,
    required this.type,
    this.isRead = false,
  });

  factory StoreNotification.fromJson(Map<String, dynamic> j) {
    return StoreNotification(
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

enum StoreNotificationType {
  newOrder,
  orderDelivered,
  settlement,
  strike,
  deliveryAssigned,
  announcement,
  offer,
  system,
}

StoreNotificationType _typeFromString(String t) {
  switch (t) {
    case 'new_order':
      return StoreNotificationType.newOrder;
    case 'order_delivered':
      return StoreNotificationType.orderDelivered;
    case 'settlement':
      return StoreNotificationType.settlement;
    case 'strike_warning':
    case 'store_suspended':
      return StoreNotificationType.strike;
    case 'delivery_assigned':
      return StoreNotificationType.deliveryAssigned;
    case 'announcement':
      return StoreNotificationType.announcement;
    case 'offer':
      return StoreNotificationType.offer;
    default:
      return StoreNotificationType.system;
  }
}

/// Manages notification history for the store app.
///
/// Call [loadFromBackend] once the user is authenticated.
/// FCM messages are added live via [add].
class StoreNotificationProvider extends ChangeNotifier {
  // Map notif_id → StoreNotification for O(1) dedup.
  final Map<String, StoreNotification> _byId = {};

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  /// Sorted newest-first.
  List<StoreNotification> get notifications {
    final list = _byId.values.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return List.unmodifiable(list);
  }

  int get unreadCount => _byId.values.where((n) => !n.isRead).length;

  // ── Backend sync ─────────────────────────────────────────────────────────────

  Future<void> loadFromBackend() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient().get('/notifications/me');
      final list = (data is Map ? data['notifications'] as List? : null) ?? [];
      for (final raw in list) {
        final n = StoreNotification.fromJson(raw as Map<String, dynamic>);
        if (n.id.isNotEmpty) _byId[n.id] = n;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markReadOnBackend(String id) async {
    try {
      await ApiClient().patch('/notifications/$id/read');
    } catch (_) {}
  }

  Future<void> markAllReadOnBackend() async {
    try {
      await ApiClient().patch('/notifications/me/read-all');
    } catch (_) {}
  }

  Future<void> clearAllOnBackend() async {
    try {
      await ApiClient().delete('/notifications/me');
    } catch (_) {}
  }

  // ── Live FCM additions ────────────────────────────────────────────────────────

  void add({
    required String title,
    required String body,
    String? orderId,
    StoreNotificationType type = StoreNotificationType.system,
    String? id,
  }) {
    final notifId = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    if (_byId.containsKey(notifId)) return;
    _byId[notifId] = StoreNotification(
      id: notifId,
      title: title,
      body: body,
      receivedAt: DateTime.now(),
      orderId: orderId,
      type: type,
    );
    notifyListeners();
  }

  // ── Local state mutations ─────────────────────────────────────────────────────

  void markRead(String id) {
    final n = _byId[id];
    if (n != null && !n.isRead) {
      n.isRead = true;
      notifyListeners();
      markReadOnBackend(id);
    }
  }

  void markAllRead() {
    bool changed = false;
    for (final n in _byId.values) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      markAllReadOnBackend();
    }
  }

  void clearAll() {
    _byId.clear();
    notifyListeners();
    clearAllOnBackend();
  }

  /// Infer the [StoreNotificationType] from the FCM `type` field.
  static StoreNotificationType typeFromData(Map<String, String> data) {
    return _typeFromString(data['type'] ?? '');
  }
}
