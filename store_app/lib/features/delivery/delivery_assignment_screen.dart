import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/order.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/order_provider.dart';
import '../../core/services/location_ws_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class DeliveryAssignmentScreen extends StatefulWidget {
  final String? orderId;
  const DeliveryAssignmentScreen({super.key, this.orderId});

  @override
  State<DeliveryAssignmentScreen> createState() => _DeliveryAssignmentScreenState();
}

class _DeliveryAssignmentScreenState extends State<DeliveryAssignmentScreen> {
  Order? _order;
  bool _loading = true;
  bool _busy = false;
  bool _streaming = false;
  final _streamer = DeliveryLocationStreamer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = widget.orderId ??
        context.read<DeliveryProvider>().activeAssignment?.orderId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final order = await context.read<OrderProvider>().loadOrder(id);
      if (mounted) {
        setState(() => _order = order);
        if (order.status == 'out_for_delivery') {
          await _startStreaming(order.orderId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startStreaming(String orderId) async {
    if (_streaming) return;
    try {
      await _streamer.start(orderId);
      if (mounted) setState(() => _streaming = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Location streaming failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _streamer.stop();
    super.dispose();
  }

  Future<void> _markDelivered() async {
    if (_order == null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<DeliveryProvider>().markDelivered(_order!.orderId);
      await _streamer.stop();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _openInMaps() async {
    if (_order == null) return;
    final lat = _order!.customerAddress.lat;
    final lng = _order!.customerAddress.lng;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=two_wheeler');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Active Delivery',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          if (_streaming)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: AppColors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('LIVE',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green)),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? Center(
                  child: Text('No active assignment',
                      style: GoogleFonts.inter(color: c.textHint)))
              : _buildBody(c, _order!),
    );
  }

  Widget _buildBody(DhavColors c, Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deliver to ${order.customerAddress.area}',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary)),
                      Text(order.customerAddress.oneLine,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: c.textHint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: c.iconBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 20,
                    backgroundColor: c.divider,
                    child: Icon(Icons.person_rounded, color: c.textHint, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: c.textHint)),
                      Text(order.customerAddress.label,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('ITEMS',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textHint,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: c.iconBg, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.inventory_2_outlined,
                          color: c.textHint, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.itemName,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: c.textPrimary)),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: c.iconBg, borderRadius: BorderRadius.circular(8)),
                      child: Text('×${item.quantity}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.textSecondary)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: c.iconBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded,
                    color: AppColors.green, size: 20),
                const SizedBox(width: 10),
                Text('Payment',
                    style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
                const Spacer(),
                Text(order.paymentMethod.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: c.iconBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text('Your Earnings',
                    style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
                const Spacer(),
                Text('₹${order.deliveryFee.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _busy ? null : _markDelivered,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.4))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.done_all_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text('MARK AS DELIVERED',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.5)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openInMaps,
            icon: const Icon(Icons.open_in_new_rounded,
                color: AppColors.primary, size: 18),
            label: Text('Open in Google Maps',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.divider, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}
