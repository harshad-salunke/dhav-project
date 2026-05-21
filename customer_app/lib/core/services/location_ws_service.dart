import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

/// Customer-side WebSocket service that RECEIVES delivery boy GPS location.
class LocationWsService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;

  String? _orderId;
  Function(LatLng)? onLocationUpdate;
  bool _active = false;

  Future<void> startListening(String orderId, Function(LatLng) onUpdate) async {
    _orderId = orderId;
    onLocationUpdate = onUpdate;
    _active = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (!_active || _orderId == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken(true);

      final uri = Uri.parse(
          '${ApiConfig.wsBaseUrl}/ws/order/$_orderId/location?role=customer&token=$token');

      _channel = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString()) as Map<String, dynamic>;
            final lat = (json['lat'] as num).toDouble();
            final lng = (json['lng'] as num).toDouble();
            onLocationUpdate?.call(LatLng(lat, lng));
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_active) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  void stop() {
    _active = false;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
