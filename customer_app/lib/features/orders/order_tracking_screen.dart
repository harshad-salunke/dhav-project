import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_provider.dart';
import '../../core/services/location_ws_service.dart';
import '../../core/theme/app_colors.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  final _wsService = LocationWsService();
  GoogleMapController? _mapController;
  LatLng? _deliveryBoyPos;
  LatLng? _deliveryAddress;
  int _etaMinutes = 0;
  CustomerOrder? _order;
  Timer? _pollTimer;
  bool _wsStarted = false;

  late AnimationController _markerAnimCtrl;
  late Animation<double> _markerAnim;
  LatLng? _startPos;
  LatLng? _endPos;

  @override
  void initState() {
    super.initState();
    _markerAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _markerAnim = CurvedAnimation(
        parent: _markerAnimCtrl, curve: Curves.easeInOut);
    _markerAnim.addListener(_updateMarkerPosition);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final orderId = args?['order_id'] as String?;
    if (orderId != null && _pollTimer == null) {
      _loadOrder(orderId);
      _startPolling(orderId);
    }
  }

  Future<void> _loadOrder(String orderId) async {
    final order =
        await context.read<OrderProvider>().fetchOrder(orderId);
    if (!mounted || order == null) return;
    setState(() {
      _order = order;
      if (order.deliveryLat != null && order.deliveryLng != null) {
        _deliveryAddress =
            LatLng(order.deliveryLat!, order.deliveryLng!);
      }
    });

    if (order.status == 'out_for_delivery' && !_wsStarted) {
      _wsStarted = true;
      _wsService.startListening(orderId, _onLocationUpdate);
    }
  }

  void _startPolling(String orderId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final order =
          await context.read<OrderProvider>().fetchOrder(orderId);
      if (!mounted || order == null) return;
      setState(() => _order = order);

      if (order.status == 'out_for_delivery' && !_wsStarted) {
        _wsStarted = true;
        _wsService.startListening(orderId, _onLocationUpdate);
      }
    });
  }

  void _onLocationUpdate(LatLng newPos) {
    _startPos = _deliveryBoyPos ?? newPos;
    _endPos = newPos;
    _markerAnimCtrl.reset();
    _markerAnimCtrl.forward();

    if (_deliveryAddress != null) {
      final dist = _haversine(newPos, _deliveryAddress!);
      setState(() => _etaMinutes = (dist / 0.5).ceil());
    }
  }

  void _updateMarkerPosition() {
    if (_startPos == null || _endPos == null) return;
    final t = _markerAnim.value;
    setState(() {
      _deliveryBoyPos = LatLng(
        _startPos!.latitude +
            (_endPos!.latitude - _startPos!.latitude) * t,
        _startPos!.longitude +
            (_endPos!.longitude - _startPos!.longitude) * t,
      );
    });
    // Camera follow
    _mapController?.animateCamera(
        CameraUpdate.newLatLng(_deliveryBoyPos!));
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * (3.14159 / 180);
    final dLng = (b.longitude - a.longitude) * (3.14159 / 180);
    final h = (dLat / 2) * (dLat / 2) +
        (a.latitude * (3.14159 / 180)).abs() *
            (b.latitude * (3.14159 / 180)).abs() *
            (dLng / 2) *
            (dLng / 2);
    return r * 2 * (h < 1 ? h : 1);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsService.stop();
    _markerAnimCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _order?.status ?? 'pending';
    final isOutForDelivery = status == 'out_for_delivery';
    final isDelivered = status == 'delivered';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Track Order',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (_order?.orderId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '#${_order!.orderId.substring(0, 8).toUpperCase()}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status timeline
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            color: AppColors.surface,
            child: _buildTimeline(status),
          ),

          // Live map (only out_for_delivery)
          if (isOutForDelivery || _deliveryBoyPos != null)
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _deliveryBoyPos ??
                          _deliveryAddress ??
                          const LatLng(18.5031, 73.8122),
                      zoom: 15,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    markers: {
                      if (_deliveryBoyPos != null)
                        Marker(
                          markerId: const MarkerId('delivery_boy'),
                          position: _deliveryBoyPos!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange),
                          infoWindow: InfoWindow(
                              title: _order?.deliveryBoyName ??
                                  'Delivery Boy'),
                        ),
                      if (_deliveryAddress != null)
                        Marker(
                          markerId: const MarkerId('destination'),
                          position: _deliveryAddress!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen),
                          infoWindow:
                              const InfoWindow(title: 'Your Location'),
                        ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                  if (_etaMinutes > 0)
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'Arriving in ~$_etaMinutes min',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Expanded(
              child: isDelivered
                  ? _buildDeliveredState()
                  : _buildWaitingState(status),
            ),

          // Bottom info strip
          if (!isDelivered)
            _buildBottomStrip(),
        ],
      ),
    );
  }

  Widget _buildTimeline(String status) {
    final steps = [
      ('Order Placed', Icons.check_circle_rounded,
          _isComplete('placed', status)),
      ('Store Accepted', Icons.storefront_rounded,
          _isComplete('accepted', status)),
      ('Being Packed', Icons.inventory_2_rounded,
          _isComplete('packed', status)),
      ('Out for Delivery', Icons.delivery_dining_rounded,
          _isComplete('out_for_delivery', status)),
      ('Delivered', Icons.home_rounded, _isComplete('delivered', status)),
    ];

    return Row(
      children: steps
          .asMap()
          .entries
          .map((e) => Expanded(
                child: Column(
                  children: [
                    Icon(
                      e.value.$2,
                      color: e.value.$3
                          ? AppColors.success
                          : AppColors.border,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.value.$1,
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          color: e.value.$3
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                          fontWeight: e.value.$3
                              ? FontWeight.w600
                              : FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  bool _isComplete(String step, String status) {
    const order = [
      'placed',
      'pending',
      'accepted',
      'store_accepted',
      'packed',
      'out_for_delivery',
      'delivered'
    ];
    final stepIdx = order.indexOf(step);
    final statusIdx = order.indexOf(status);
    return stepIdx <= statusIdx;
  }

  Widget _buildWaitingState(String status) {
    final messages = {
      'pending': 'Broadcasting to nearby stores…',
      'broadcasting': 'Looking for available stores…',
      'accepted': 'Store accepted! Packing your order…',
      'store_accepted': 'Store accepted! Packing your order…',
      'packed': 'Order packed, assigning delivery boy…',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            messages[status] ?? 'Processing your order…',
            style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: AppColors.successLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
                size: 56, color: AppColors.success),
          ),
          const SizedBox(height: 20),
          Text('Order Delivered!',
              style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Your order has been delivered successfully.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/home'),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _order?.deliveryBoyName ?? 'Delivery Boy',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                Text('Your delivery partner',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_order?.deliveryBoyPhone != null)
            GestureDetector(
              onTap: () => launchUrl(
                  Uri.parse('tel:${_order!.deliveryBoyPhone}')),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
        ],
      ),
    );
  }
}
