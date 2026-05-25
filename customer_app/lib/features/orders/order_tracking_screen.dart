import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_routes.dart';
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
  bool _navigatedToDelivered = false;

  // Smooth marker animation
  late AnimationController _markerAnimCtrl;
  late Animation<double> _markerAnim;
  LatLng? _startPos;
  LatLng? _endPos;

  // Pulsing dot for active timeline step
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _stepLabels = [
    'Order Placed',
    'Store Accepted',
    'Being Packed',
    'Out for Delivery',
    'Delivered',
  ];

  static const _stepSubtitles = [
    'Your order was placed',
    'Store is preparing your order',
    'Your items are being packed',
    'On the way to your location',
    'Enjoy your order!',
  ];

  int get _currentStep {
    final s = _order?.status ?? 'pending';
    if (s == 'pending' || s == 'broadcasting') return 0;
    if (s == 'accepted' || s == 'store_accepted') return 1;
    if (s == 'packed') return 2;
    if (s == 'out_for_delivery') return 3;
    if (s == 'delivered') return 4;
    return 0;
  }

  @override
  void initState() {
    super.initState();

    // Marker smooth-glide animation
    _markerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _markerAnim = CurvedAnimation(
      parent: _markerAnimCtrl,
      curve: Curves.easeInOut,
    );
    _markerAnim.addListener(_updateMarkerPosition);

    // Pulsing dot animation (repeating)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
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
    final order = await context.read<OrderProvider>().fetchOrder(orderId);
    if (!mounted || order == null) return;
    setState(() {
      _order = order;
      if (order.deliveryLat != null && order.deliveryLng != null) {
        _deliveryAddress = LatLng(order.deliveryLat!, order.deliveryLng!);
      }
    });
    _checkDelivered(order);
    if (order.status == 'out_for_delivery' && !_wsStarted) {
      _wsStarted = true;
      _wsService.startListening(orderId, _onLocationUpdate);
    }
  }

  void _startPolling(String orderId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final order = await context.read<OrderProvider>().fetchOrder(orderId);
      if (!mounted || order == null) return;
      setState(() => _order = order);
      _checkDelivered(order);
      if (order.status == 'out_for_delivery' && !_wsStarted) {
        _wsStarted = true;
        _wsService.startListening(orderId, _onLocationUpdate);
      }
    });
  }

  void _checkDelivered(CustomerOrder order) {
    if (order.status == 'delivered' && !_navigatedToDelivered) {
      _navigatedToDelivered = true;
      _pollTimer?.cancel();
      _wsService.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.orderDelivered,
            arguments: order,
          );
        }
      });
    }
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
        _startPos!.latitude + (_endPos!.latitude - _startPos!.latitude) * t,
        _startPos!.longitude + (_endPos!.longitude - _startPos!.longitude) * t,
      );
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(_deliveryBoyPos!));
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
    _pulseCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _order?.status ?? 'pending';
    final isOutForDelivery = status == 'out_for_delivery';
    final deliveryBoyAssigned = _order?.deliveryBoyName != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _order != null
                  ? 'Order #${_order!.orderId.substring(0, 8).toUpperCase()}'
                  : 'Track Order',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            if (_order?.storeName != null)
              Text(
                _order!.storeName!,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              'Need Help?',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Timeline section ──
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Status',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 16),
                _buildVerticalTimeline(),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'I have a problem with this order',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Map / waiting section ──
          Expanded(
            child: isOutForDelivery || _deliveryBoyPos != null
                ? _buildMapSection()
                : _buildWaitingState(status),
          ),

          // ── Delivery boy card ──
          if (deliveryBoyAssigned) _buildDeliveryBoyCard(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Vertical timeline
  // ─────────────────────────────────────────────
  Widget _buildVerticalTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_stepLabels.length, (i) {
        final isCompleted = i < _currentStep;
        final isActive = i == _currentStep;
        final isLast = i == _stepLabels.length - 1;
        return _buildTimelineStep(
          index: i,
          label: _stepLabels[i],
          subtitle: _getStepSubtitle(i),
          isCompleted: isCompleted,
          isActive: isActive,
          isLast: isLast,
        );
      }),
    );
  }

  String _getStepSubtitle(int i) {
    if (i == 1 && _order?.storeName != null) {
      return '${_order!.storeName} is preparing your order';
    }
    if (i == 3 && _order?.deliveryBoyName != null) {
      return '${_order!.deliveryBoyName} is on the way';
    }
    return _stepSubtitles[i];
  }

  Widget _buildTimelineStep({
    required int index,
    required String label,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + connector line
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _buildDot(isCompleted, isActive),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isCompleted ? AppColors.success : AppColors.border,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Text content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : isCompleted
                              ? FontWeight.w600
                              : FontWeight.w400,
                      color: isCompleted || isActive
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                  if (isCompleted || isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Status indicator on right for active/completed
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: 0.5 + 0.5 * _pulseAnim.value,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'In Progress',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isCompleted, bool isActive) {
    if (isCompleted) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      );
    }
    if (isActive) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary
                    .withValues(alpha: 0.35 * _pulseAnim.value),
                blurRadius: 8,
                spreadRadius: 3 * _pulseAnim.value,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    // Locked future step
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Map section
  // ─────────────────────────────────────────────
  Widget _buildMapSection() {
    return Stack(
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
                    title: _order?.deliveryBoyName ?? 'Delivery Partner'),
              ),
            if (_deliveryAddress != null)
              Marker(
                markerId: const MarkerId('destination'),
                position: _deliveryAddress!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(title: 'Your Location'),
              ),
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
        ),
        // ETA chip
        if (_etaMinutes > 0)
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Arriving in ~$_etaMinutes min',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Waiting state (before out_for_delivery)
  // ─────────────────────────────────────────────
  Widget _buildWaitingState(String status) {
    final messages = {
      'pending': 'Looking for nearby stores…',
      'broadcasting': 'Notifying stores in your area…',
      'accepted': 'Store accepted your order!',
      'store_accepted': 'Store accepted your order!',
      'packed': 'Order packed, assigning delivery partner…',
    };
    final icons = {
      'pending': Icons.radar_rounded,
      'broadcasting': Icons.cell_tower_rounded,
      'accepted': Icons.storefront_rounded,
      'store_accepted': Icons.storefront_rounded,
      'packed': Icons.inventory_2_rounded,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icons[status] ?? Icons.hourglass_empty_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            messages[status] ?? 'Processing your order…',
            style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when there\'s an update',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Delivery boy card (bottom strip)
  // ─────────────────────────────────────────────
  Widget _buildDeliveryBoyCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                size: 24, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _order?.deliveryBoyName ?? 'Delivery Partner',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                Text(
                  'Your delivery partner',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Call button
          if (_order?.deliveryBoyPhone != null)
            GestureDetector(
              onTap: () => launchUrl(
                  Uri.parse('tel:${_order!.deliveryBoyPhone}')),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}
