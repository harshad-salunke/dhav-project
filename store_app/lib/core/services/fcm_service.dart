import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  final title = data['title'] ?? message.notification?.title ??
      (isOrder ? 'New Order! 🛒' : 'New Delivery Assignment!');
  final body = data['body'] ?? message.notification?.body ??
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
    sound: RawResourceAndroidNotificationSound('order_alert'),
    // notificationRingtone usage makes audio play at RINGTONE volume — bypasses
    // silent / vibrate / DND modes (same behavior as an incoming phone call).
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
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

    final settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (kDebugMode) {
      print('[FCM] Permission status: ${settings.authorizationStatus}');
    }
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    await _initLocalNotifications();

    _fgSub = FirebaseMessaging.onMessage.listen((msg) {
      if (kDebugMode) {
        print('[FCM] Foreground message: ${msg.data}');
      }
      _handleMessage(msg);
    });
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleMessage(initial);

    if (kDebugMode) {
      final token = await messaging.getToken();
      print('[FCM] ====== FCM TOKEN ======');
      print(token);
      print('[FCM] =======================');
    }
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

    final androidPlugin = _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+ requires explicit POST_NOTIFICATIONS permission.
    final granted = await androidPlugin?.requestNotificationsPermission();
    if (kDebugMode) {
      print('[FCM] POST_NOTIFICATIONS granted: $granted');
    }

    // Android 14+ requires explicit permission for full-screen intent (Uber-style
    // popup that bypasses the lock screen / launches the activity automatically).
    final fsiGranted = await androidPlugin?.requestFullScreenIntentPermission();
    if (kDebugMode) {
      print('[FCM] FULL_SCREEN_INTENT granted: $fsiGranted');
    }

    // Delete before recreating — Android never updates sound on an existing
    // channel, so we force a fresh channel every cold start.
    await androidPlugin?.deleteNotificationChannel(_channelId);

    final channel = AndroidNotificationChannel(
      _channelId,
      'Incoming Orders',
      description: 'High-priority alerts for new orders',
      importance: Importance.max,
      playSound: true,
      sound: _alertSound,
      enableVibration: true,
      // ringtone volume + bypass silent / DND — same as an incoming call.
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    );
    await androidPlugin?.createNotificationChannel(channel);
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
          volume: 1.0, mode: PlayerMode.mediaPlayer);
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
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    );
    await _localNotifs.show(
      data['order_id'].hashCode,
      notif?.title ?? 'New Order! 🛒',
      notif?.body ??
          '${data['item_count'] ?? '?'} items · ₹${data['total'] ?? '?'} — Accept now!',
      NotificationDetails(android: androidDetails),
      payload: data['order_id'],
    );
  }

  Future<void> _triggerDeliveryAlert(
    Map<String, String> data, {
    RemoteNotification? notif,
  }) async {
    try {
      await _player.play(AssetSource('sounds/order_alert.mp3'),
          volume: 1.0, mode: PlayerMode.mediaPlayer);
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
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    );
    await _localNotifs.show(
      data['order_id'].hashCode,
      notif?.title ?? 'New Delivery Assignment!',
      notif?.body ?? 'You have a new delivery assignment',
      NotificationDetails(android: androidDetails),
      payload: data['order_id'],
    );
  }

  /// Returns the order_id that launched the app via a tapped notification
  /// (cold-start case), or null if the app was launched normally. Call this
  /// after listeners are attached so the navigation runs.
  Future<String?> getInitialNotificationOrderId() async {
    final details = await _localNotifs.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) return payload;
    }
    return null;
  }

  /// Method channel to the native side (DhavMessagingService / MainActivity)
  /// which force-launches MainActivity when an order arrives while the
  /// screen is on. Native caches the order_id in MainActivity; we pull it
  /// here once Dart's navigator is ready.
  static const MethodChannel _incomingOrderChannel =
      MethodChannel('com.dhav.store_app/incoming_order');

  /// Returns `{order_id, type}` from the native side if a force-launch is
  /// pending, otherwise null. Native clears the pending state on read.
  Future<Map<String, String?>?> consumePendingNativeOrder() async {
    try {
      final result = await _incomingOrderChannel
          .invokeMapMethod<String, dynamic>('consumePendingOrder');
      if (result == null) return null;
      return {
        'order_id': result['order_id'] as String?,
        'type': result['type'] as String?,
      };
    } catch (e) {
      if (kDebugMode) print('[FCM] consumePendingNativeOrder failed: $e');
      return null;
    }
  }

  /// Listen for native-side push notifying us a new order intent has arrived
  /// (used when the app is already running and `onNewIntent` fires). Pass
  /// a callback that pulls + navigates.
  void onNativePendingOrderAvailable(VoidCallback callback) {
    _incomingOrderChannel.setMethodCallHandler((call) async {
      if (call.method == 'pendingOrderAvailable') {
        callback();
      }
      return null;
    });
  }

  /// Starts the order ringtone on loop at ringtone volume. Call from the
  /// IncomingOrderScreen / DeliveryIncomingAssignmentScreen as soon as the
  /// screen mounts so the audio keeps playing like a phone call until the
  /// user accepts or rejects (use [stopRingtone] then).
  Future<void> startRingtone() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
          ),
        ),
      );
      await _player.play(
        AssetSource('sounds/order_alert.mp3'),
        volume: 1.0,
        mode: PlayerMode.mediaPlayer,
      );
    } catch (e) {
      if (kDebugMode) print('[FCM] startRingtone failed: $e');
    }
  }

  Future<void> stopRingtone() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      if (kDebugMode) print('[FCM] stopRingtone failed: $e');
    }
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
