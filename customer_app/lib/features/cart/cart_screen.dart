import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressCtrl = TextEditingController();
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _addressCtrl.text = cart.deliveryAddress;
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a delivery address')));
      return;
    }
    cart.setDeliveryAddress(_addressCtrl.text.trim());

    setState(() => _placing = true);
    final orders = context.read<OrderProvider>();
    final order = await orders.placeOrder(
      items: cart.toOrderItems(),
      deliveryAddress: _addressCtrl.text.trim(),
      deliveryLat: cart.deliveryLat,
      deliveryLng: cart.deliveryLng,
    );

    if (!mounted) return;
    setState(() => _placing = false);

    if (order != null) {
      cart.clear();
      Navigator.pushReplacementNamed(context, '/broadcasting',
          arguments: {'order_id': order.orderId});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(orders.error ?? 'Failed to place order'),
          backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Cart',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () => cart.clear(),
              child: Text('Clear',
                  style: GoogleFonts.inter(
                      color: AppColors.error, fontSize: 13)),
            ),
        ],
      ),
      body: cart.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Items list
                      ...cart.items.map((ci) => _ItemRow(
                            cartItem: ci,
                            onAdd: () =>
                                cart.addItem(ci.item),
                            onRemove: () =>
                                cart.removeItem(ci.item.id),
                            onDelete: () =>
                                cart.deleteItem(ci.item.id),
                          )),

                      const SizedBox(height: 20),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 16),

                      // Delivery address
                      Text('Deliver to',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText:
                              'Enter your full delivery address…',
                          prefixIcon: Icon(Icons.location_on_outlined,
                              color: AppColors.primary),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (v) =>
                            cart.setDeliveryAddress(v),
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 16),

                      // Price summary
                      _SummaryRow(label: 'Items (${cart.itemCount})',
                          value: '₹${cart.subtotal.toStringAsFixed(0)}'),
                      const _SummaryRow(
                          label: 'Delivery fee',
                          value: 'After store accepts'),
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                          children: const [
                            TextSpan(text: '💡 '),
                            TextSpan(
                                text:
                                    'A nearby kirana store will be found for your order. Delivery charge depends on store distance.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.access_time_outlined,
                              size: 14,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Usually 30–60 minutes',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              size: 14,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Cash on Delivery — pay the delivery boy',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                _buildPlaceOrderBar(cart),
              ],
            ),
    );
  }

  Widget _buildPlaceOrderBar(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: ElevatedButton(
        onPressed: _placing ? null : _placeOrder,
        child: _placing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text('Place Order • ₹${cart.subtotal.toStringAsFixed(0)}',
                style:
                    GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text('Your cart is empty',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Add items from the home screen',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/home'),
              child: const Text('Shop Now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final dynamic cartItem;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.cartItem,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 60,
              height: 60,
              color: AppColors.primaryLight,
              child: cartItem.item.imageUrl != null
                  ? Image.network(cartItem.item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.shopping_basket_outlined,
                          color: AppColors.primary))
                  : const Icon(Icons.shopping_basket_outlined,
                      color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cartItem.item.name,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(cartItem.item.unit,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.remove,
                      color: Colors.white, size: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${cartItem.quantity}',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.add,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
