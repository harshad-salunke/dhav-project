import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import 'api_client.dart';

/// FCM data-message shape sent from backend for new orders:
/// {
///   "type": "new_order",
///   "order_id": "...",
///   "item_count": "3",
///   "distance_km": "0.8",
///   "earning": "42.50"
/// }
typedef IncomingOrderHandler = void Function(Map<String, String> data);
typedef DeliveryAssignedHandler = void Function(Map<String, String> data);

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Body intentionally minimal — the local-notification channel set up in
  // setupFcm() will surface the high-priority alert. We can't navigate from
  // here, but the notification opens the app which then reads the pending
  // order from the data payload via getInitialMessage().
}

class FcmService {
  FcmService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  final _player = AudioPlayer();
  final _localNotifs = FlutterLocalNotificationsPlugin();

  IncomingOrderHandler? onIncomingOrder;
  DeliveryAssignedHandler? onDeliveryAssigned;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openSub;

  static const _incomingChannelId = 'dhav_incoming_orders';

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    await _initLocalNotifications();

    _fgSub = FirebaseMessaging.onMessage.listen(_handleMessage);
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Cold-start case: app was launched by tapping a notification.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleMessage(initial);
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifs.initialize(settings);

    const channel = AndroidNotificationChannel(
      _incomingChannelId,
      'Incoming Orders',
      description: 'High-priority alerts for new orders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _handleMessage(RemoteMessage message) {
    final data = <String, String>{
      for (final e in message.data.entries) e.key: e.value.toString(),
    };

    if (data['type'] == 'new_order') {
      _triggerOrderAlert(data, notif: message.notification);
      onIncomingOrder?.call(data);
    } else if (data['type'] == 'delivery_assigned') {
      _triggerDeliveryAlert(data, notif: message.notification);
      onDeliveryAssigned?.call(data);
    }
  }

  Future<void> _triggerOrderAlert(
    Map<String, String> data, {
    RemoteNotification? notif,
  }) async {
    // Loud ring + vibrate even if app is in foreground.
    try {
      await _player.play(AssetSource('sounds/order_alert.mp3'),
          volume: 1.0, mode: PlayerMode.lowLatency);
    } catch (e) {
      if (kDebugMode) print('order alert sound failed: $e');
    }
    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib) {
        Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500],
            intensities: [0, 255, 0, 255, 0, 255]);
      }
    } catch (_) {}

    // Show high-priority local notification so it surfaces even in background.
    const androidDetails = AndroidNotificationDetails(
      _incomingChannelId,
      'Incoming Orders',
      channelDescription: 'High-priority alerts for new orders',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifs.show(
      data['order_id'].hashCode,
      notif?.title ?? 'New Order!',
      notif?.body ??
          '${data['item_count'] ?? '?'} items • ${data['distance_km'] ?? '?'} km',
      details,
      payload: data['order_id'],
    );
  }

  Future<void> _triggerDeliveryAlert(
    Map<String, String> data, {
    RemoteNotification? notif,
  }) async {
    try {
      await _player.play(AssetSource('sounds/order_alert.mp3'),
          volume: 1.0, mode: PlayerMode.lowLatency);
    } catch (e) {
      if (kDebugMode) print('delivery alert sound failed: $e');
    }
    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib) {
        Vibration.vibrate(
            pattern: [0, 400, 200, 400], intensities: [0, 255, 0, 255]);
      }
    } catch (_) {}

    const androidDetails = AndroidNotificationDetails(
      _incomingChannelId,
      'Incoming Orders',
      channelDescription: 'High-priority alerts for new orders',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifs.show(
      data['order_id'].hashCode,
      notif?.title ?? 'New Delivery Assignment!',
      notif?.body ?? 'You have a new delivery assignment',
      details,
      payload: data['order_id'],
    );
  }

  /// Returns the current FCM token. Caller must POST it to /stores/me/fcm-token.
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  /// Pushes the latest FCM token to the backend for the signed-in store owner.
  Future<void> syncTokenToBackend() async {
    final token = await getToken();
    if (token == null) return;
    try {
      await _api.patch('/stores/me/fcm-token', body: {'fcm_token': token});
    } catch (e) {
      if (kDebugMode) print('syncTokenToBackend failed: $e');
    }
  }

  /// Pushes the latest FCM token for the signed-in delivery boy.
  Future<void> syncDeliveryTokenToBackend() async {
    final token = await getToken();
    if (token == null) return;
    try {
      await _api.patch('/delivery/me/fcm-token', body: {'fcm_token': token});
    } catch (e) {
      if (kDebugMode) print('syncDeliveryTokenToBackend failed: $e');
    }
  }

  /// Listen for token rotation and re-sync (store owner).
  void listenForTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => syncTokenToBackend());
  }

  /// Listen for token rotation and re-sync (delivery boy).
  void listenForDeliveryTokenRefresh() {
    FirebaseMessaging.instance
        .onTokenRefresh
        .listen((_) => syncDeliveryTokenToBackend());
  }

  Future<void> dispose() async {
    await _fgSub?.cancel();
    await _openSub?.cancel();
    await _player.dispose();
  }
}
