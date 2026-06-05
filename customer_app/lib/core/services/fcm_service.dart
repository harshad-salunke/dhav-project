import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../providers/notification_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handled by OS notification tray — no special action needed
}

class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey;

  /// Injected after the provider tree is ready. Used to accumulate
  /// in-app notification history shown in the Notifications screen.
  NotificationProvider? notificationProvider;

  /// Broadcast stream of order IDs from incoming order-update pushes.
  /// Screens (broadcasting, tracking) listen to react INSTANTLY to a status
  /// change instead of waiting for the next poll. Broadcast = many listeners.
  final StreamController<String> _orderUpdateController =
      StreamController<String>.broadcast();
  Stream<String> get orderUpdates => _orderUpdateController.stream;

  FcmService({required this.navigatorKey});

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'dhav_customer_orders',
    'DHAV Order Updates',
    description: 'Notifications about your DHAV orders',
    importance: Importance.high,
  );

  Future<void> init() async {
    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await _messaging.requestPermission(alert: true, sound: true, badge: true);

    // Create notification channel (Android 8+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // When app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Cold start tap
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleMessageTap(initial);
  }

  Future<String?> getToken() async => _messaging.getToken();

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final orderId = data['order_id'] as String?;
    final title = message.notification?.title ?? 'DHAV Order Update';
    final body = message.notification?.body ?? '';

    // Show OS notification
    _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: orderId,
    );

    // Accumulate in-app notification history
    notificationProvider?.add(
      title: title,
      body: body,
      orderId: orderId,
      type: NotificationProvider.typeFromData(data),
    );

    if (orderId != null) _orderUpdateController.add(orderId);
  }

  void _handleMessageTap(RemoteMessage message) {
    final orderId = message.data['order_id'] as String?;
    if (orderId != null) {
      navigatorKey.currentState?.pushNamed(
        '/order-tracking',
        arguments: {'order_id': orderId},
      );
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final orderId = response.payload;
    if (orderId != null && orderId.isNotEmpty) {
      navigatorKey.currentState?.pushNamed(
        '/order-tracking',
        arguments: {'order_id': orderId},
      );
    }
  }

  void dispose() {
    // FirebaseMessaging listeners are persistent; just close our stream.
    _orderUpdateController.close();
  }
}
