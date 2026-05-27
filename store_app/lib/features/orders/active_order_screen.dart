import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/order.dart';
import '../../core/models/store.dart';
import '../../core/providers/order_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';

/// Maps backend order.status → step index in the local stepper.
const Map<String, int> _statusToStep = {
  'accepted': 0,
  'packed': 2,
  'out_for_delivery': 3,
  'delivered': 4,
};

class ActiveOrderScreen extends StatefulWidget {
  final String? orderId;
  const ActiveOrderScreen({super.key, this.orderId});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  Order? _order;
  bool _loading = true;
  bool _busy = false;
  String? _selectedBoyId;

  final List<Map<String, dynamic>> _steps = [
    {'label': 'Order Accepted', 'desc': 'Preparing order', 'icon': Icons.check_circle_outline},
    {'label': 'Assign Delivery Boy', 'desc': 'Select delivery partner', 'icon': Icons.person_add_alt_1_rounded},
    {'label': 'Mark as Packed', 'desc': 'Items are ready', 'icon': Icons.inventory_2_rounded},
    {'label': 'Dispatched', 'desc': 'Out for delivery', 'icon': Icons.local_shipping_rounded},
    {'label': 'Delivered', 'desc': 'Order complete', 'icon': Icons.done_all_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = widget.orderId;
    if (id == null) {
      // Fall back to the active order from the list, if any.
      final active = context.read<OrderProvider>().activeOrder;
      if (active != null) {
        setState(() {
          _order = active;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
      await context.read<StoreProvider>().loadDeliveryBoys();
      return;
    }
    final orderProv = context.read<OrderProvider>();
    final storeProv = context.read<StoreProvider>();
    try {
      final order = await orderProv.loadOrder(id);
      await storeProv.loadDeliveryBoys();
      if (mounted) {
        setState(() {
          _order = order;
          _selectedBoyId = order.assignedDeliveryBoyId;
        });
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

  int get _currentStep {
    if (_order == null) return 0;
    final base = _statusToStep[_order!.status] ?? 0;
    // If accepted but boy already assigned, advance to the "mark as packed" gate.
    if (_order!.status == 'accepted' && _order!.assignedDeliveryBoyId != null) return 1;
    return base;
  }

  Future<void> _advance() async {
    if (_order == null || _busy) return;
    setState(() => _busy = true);
    final orders = context.read<OrderProvider>();
    try {
      switch (_order!.status) {
        case 'accepted':
          if (_order!.assignedDeliveryBoyId == null) {
            if (_selectedBoyId == null) {
              _toast('Select a delivery partner first');
              return;
            }
            await orders.assignDeliveryBoy(_order!.orderId, _selectedBoyId!);
          } else {
            await orders.markPacked(_order!.orderId);
          }
          break;
        case 'packed':
          await orders.markDispatched(_order!.orderId);
          break;
        case 'out_for_delivery':
          await orders.markDelivered(_order!.orderId);
          break;
      }
      _order = orders.selected;
    } catch (e) {
      _toast('Action failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _ctaLabel() {
    if (_order == null) return 'Loading...';
    switch (_order!.status) {
      case 'accepted':
        return _order!.assignedDeliveryBoyId == null
            ? 'Assign Delivery Boy'
            : 'Mark as Packed';
      case 'packed':
        return 'Confirm Dispatch';
      case 'out_for_delivery':
        return 'Mark Delivered';
      default:
        return 'Completed';
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Active Order',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
      ),
      body: _loading
          ? const OrderDetailShimmer()
          : _order == null
              ? _emptyView(c)
              : _buildBody(c, _order!),
    );
  }

  Widget _emptyView(DhavColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: c.textHint),
          const SizedBox(height: 12),
          Text('No active order',
              style: GoogleFonts.inter(fontSize: 16, color: c.textHint)),
        ],
      ),
    );
  }

  Widget _buildBody(DhavColors c, Order order) {
    final terminal = order.isTerminal;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.orderId.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                        '${order.itemCount} Items • ₹${order.totalCustomerAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: c.greenBg, borderRadius: BorderRadius.circular(8)),
                child: Text(order.paymentMethod.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green)),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _addressCard(c, order),
                const SizedBox(height: 16),
                Text('ORDER ITEMS',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.textHint,
                        letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ...order.items.map((item) => _OrderItemTile(item: item)),
                const SizedBox(height: 20),
                if (order.status == 'accepted' && order.assignedDeliveryBoyId == null)
                  _deliveryBoyPicker(c),
                Text('ORDER PROGRESS',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.textHint,
                        letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ..._steps.asMap().entries.map((e) => _StepTile(
                      index: e.key,
                      step: e.value,
                      currentStep: _currentStep,
                      isLast: e.key == _steps.length - 1,
                    )),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (!terminal)
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _busy ? null : _advance,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.4))
                      : Text(
                          _ctaLabel(),
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _addressCard(DhavColors c, Order order) {
    final a = order.customerAddress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DELIVER TO',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textHint,
                  letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(a.oneLine,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('${a.city} ${a.pincode ?? ''}',
              style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
          if (order.deliveryBoyName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.delivery_dining_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(order.deliveryBoyName!,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                const Spacer(),
                if (order.deliveryBoyPhone != null)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded,
                        color: AppColors.green, size: 18),
                    onPressed: () =>
                        launchUrl(Uri.parse('tel:${order.deliveryBoyPhone}')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _deliveryBoyPicker(DhavColors c) {
    final boys = context.watch<StoreProvider>().deliveryBoys;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ASSIGN DELIVERY PARTNER',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.textHint,
                letterSpacing: 1.5)),
        const SizedBox(height: 12),
        if (boys.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: c.card, borderRadius: BorderRadius.circular(12)),
            child: Text('No delivery partners. Add one from the team screen.',
                style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
          )
        else
          ...boys.map((boy) => _DeliveryBoyTile(
                boy: boy,
                isSelected: _selectedBoyId == boy.deliveryBoyId,
                onTap: () =>
                    setState(() => _selectedBoyId = boy.deliveryBoyId),
              )),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final OrderItem item;
  const _OrderItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.inventory_2_outlined, color: c.textHint, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                Text('Qty: ${item.quantity} ${item.unit}',
                    style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
          Text('₹${item.totalPrice.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _DeliveryBoyTile extends StatelessWidget {
  final DeliveryBoy boy;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryBoyTile(
      {required this.boy, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final available = boy.currentOrderId == null && boy.isActive;
    return GestureDetector(
      onTap: available ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : c.card,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(color: c.divider, width: 0.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.iconBg,
              child: Icon(Icons.person_rounded, color: c.textHint, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(boy.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                  Text(available ? 'Available' : 'On Delivery',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: available ? AppColors.green : c.textHint)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> step;
  final int currentStep;
  final bool isLast;

  const _StepTile({
    required this.index,
    required this.step,
    required this.currentStep,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDone = index < currentStep;
    final isCurrent = index == currentStep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? AppColors.green
                    : isCurrent
                        ? AppColors.primary
                        : c.card,
                border: isCurrent
                    ? Border.all(color: AppColors.primary, width: 2)
                    : Border.all(color: c.divider, width: 1),
              ),
              child: Icon(
                isDone ? Icons.check_rounded : step['icon'] as IconData,
                color: isDone || isCurrent ? Colors.white : c.textHint,
                size: 16,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? AppColors.green.withValues(alpha: 0.5) : c.divider,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step['label'] as String,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isDone
                      ? AppColors.green
                      : isCurrent
                          ? c.textPrimary
                          : c.textHint,
                ),
              ),
              Text(step['desc'] as String,
                  style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
            ],
          ),
        ),
      ],
    );
  }
}
