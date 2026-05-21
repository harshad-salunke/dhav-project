import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../../firebase_options.dart';
import 'api_client.dart';

typedef IncomingOrderHandler = void Function(Map<String, String> data);
typedef DeliveryAssignedHandler = void Function(Map<String, String> data);
typedef NotificationTapHandler = void Function(String orderId);

// Background/killed handler — must be top-level and annotated.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final data = <String, String>{
    for (final e in message.data.entries) e.key: e.value.toString(),
  };

  if (data['type'] != 'new_order' && data['type'] != 'delivery_assigned') return;

  final localNotifs = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifs.initialize(const InitializationSettings(android: android));

  final isOrder = data['type'] == 'new_order';
  final title = message.notification?.title ??
      (isOrder ? 'New Order! 🛒' : 'New Delivery Assignment!');
  final body = message.notification?.body ??
      (isOrder
          ? '${data['item_count'] ?? '?'} items · ₹${data['total'] ?? '?'} — Accept now!'
          : 'You have a new delivery assignment');

  const androidDetails = AndroidNotificationDetails(
    'dhav_incoming_orders',
    'Incoming Orders',
    channelDescription: 'High-priority alerts for new orders',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
    playSound: true,
  );
  await localNotifs.show(
    data['order_id'].hashCode,
    title,
    body,
    const NotificationDetails(android: androidDetails),
    payload: data['order_id'],
  );
}

class FcmService {
  FcmService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  final _player = AudioPlayer();
  final _localNotifs = FlutterLocalNotificationsPlugin();

  IncomingOrderHandler? onIncomingOrder;
  DeliveryAssignedHandler? onDeliveryAssigned;

  /// Called when user taps a local notification from the tray (foreground/background).
  NotificationTapHandler? onNotificationTap;

  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openSub;

  static const _channelId = 'dhav_incoming_orders';
  static const _alertSound = RawResourceAndroidNotificationSound('order_alert');

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

    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleMessage(initial);
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _localNotifs.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );

    final channel = AndroidNotificationChannel(
      _channelId,
      'Incoming Orders',
      description: 'High-priority alerts for new orders',
      importance: Importance.max,
      playSound: true,
      sound: _alertSound,
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
    try {
      await _player.play(AssetSource('sounds/order_alert.mp3'),
          volume: 1.0, mode: PlayerMode.lowLatency);
    } catch (e) {
      if (kDebugMode) print('order alert sound failed: $e');
    }
    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500],
            intensities: [0, 255, 0, 255, 0, 255]);
      }
    } catch (_) {}

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Incoming Orders',
      channelDescription: 'High-priority alerts for new orders',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: _alertSound,
    );
    await _localNotifs.show(
      data['order_id'].hashCode,
      notif?.title ?? 'New Order! 🛒',
      notif?.body ??
          '${data['item_count'] ?? '?'} items · ₹${data['total'] ?? '?'} — Accept now!',
      const NotificationDetails(android: androidDetails),
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
      if (hasVib == true) {
        Vibration.vibrate(
            pattern: [0, 400, 200, 400], intensities: [0, 255, 0, 255]);
      }
    } catch (_) {}

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Incoming Orders',
      channelDescription: 'High-priority alerts for new orders',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
    );
    await _localNotifs.show(
      data['order_id'].hashCode,
      notif?.title ?? 'New Delivery Assignment!',
      notif?.body ?? 'You have a new delivery assignment',
      const NotificationDetails(android: androidDetails),
      payload: data['order_id'],
    );
  }

  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  Future<void> syncTokenToBackend() async {
    final token = await getToken();
    if (token == null) return;
    try {
      await _api.patch('/stores/me/fcm-token', body: {'fcm_token': token});
    } catch (e) {
      if (kDebugMode) print('syncTokenToBackend failed: $e');
    }
  }

  Future<void> syncDeliveryTokenToBackend() async {
    final token = await getToken();
    if (token == null) return;
    try {
      await _api.patch('/delivery/me/fcm-token', body: {'fcm_token': token});
    } catch (e) {
      if (kDebugMode) print('syncDeliveryTokenToBackend failed: $e');
    }
  }

  void listenForTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => syncTokenToBackend());
  }

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
