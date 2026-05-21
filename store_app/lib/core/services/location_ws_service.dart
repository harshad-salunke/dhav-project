import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

/// Delivery-boy side: opens a WebSocket to /ws/order/{id}/location, streams
/// the device GPS every [interval] seconds.
class DeliveryLocationStreamer {
  DeliveryLocationStreamer({this.interval = const Duration(seconds: 3)});

  final Duration interval;
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _posSub;
  Timer? _ticker;
  Position? _last;

  Future<bool> _ensurePermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<void> start(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final token = await user.getIdToken(true);

    if (!await _ensurePermission()) {
      throw StateError('Location permission denied');
    }

    _channel = WebSocketChannel.connect(
      Uri.parse('${ApiConfig.wsBaseUrl}/ws/order/$orderId/location'),
    );
    _channel!.sink.add(jsonEncode({'token': token, 'role': 'delivery_boy'}));

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) => _last = pos);

    _ticker = Timer.periodic(interval, (_) {
      final p = _last;
      if (p == null || _channel == null) return;
      _channel!.sink.add(jsonEncode({
        'lat': p.latitude,
        'lng': p.longitude,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }));
    });
  }

  Future<void> stop() async {
    _ticker?.cancel();
    await _posSub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _posSub = null;
    _ticker = null;
  }
}
