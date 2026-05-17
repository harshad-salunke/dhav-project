import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class ActiveOrderScreen extends StatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {'label': 'Order Accepted', 'desc': 'Preparing order', 'icon': Icons.check_circle_outline},
    {'label': 'Assign Delivery Boy', 'desc': 'Select delivery partner', 'icon': Icons.person_add_alt_1_rounded},
    {'label': 'Mark as Packed', 'desc': 'Items are ready', 'icon': Icons.inventory_2_rounded},
    {'label': 'Dispatched', 'desc': 'Out for delivery', 'icon': Icons.local_shipping_rounded},
    {'label': 'Delivered', 'desc': 'Order complete', 'icon': Icons.done_all_rounded},
  ];

  String _selectedDeliveryBoy = 'Ramesh Kumar';

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
        title: Text('Active Order', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('08:42', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
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
                      Text('Order #OD-9928', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary)),
                      const SizedBox(height: 4),
                      Text('4 Items • ₹1,240', style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: c.greenBg, borderRadius: BorderRadius.circular(8)),
                  child: Text('COD', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.divider)),
                  child: Icon(Icons.phone_rounded, color: c.textSecondary, size: 20),
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
                  Text('ORDER ITEMS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  ..._orderItems.map((item) => _OrderItemTile(item: item)),
                  const SizedBox(height: 20),
                  if (_currentStep == 1) ...[
                    Text('ASSIGN DELIVERY PARTNER', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    ..._deliveryBoys.map((boy) => _DeliveryBoyTile(
                          name: boy['name'] as String,
                          status: boy['status'] as String,
                          isSelected: _selectedDeliveryBoy == boy['name'],
                          onTap: () => setState(() => _selectedDeliveryBoy = boy['name'] as String),
                        )),
                    const SizedBox(height: 20),
                  ],
                  Text('ORDER PROGRESS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
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
          if (_currentStep < _steps.length - 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => setState(() => _currentStep++),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Text(
                      _getNextStepLabel(),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getNextStepLabel() {
    switch (_currentStep) {
      case 0: return 'Assign Delivery Boy';
      case 1: return 'Mark as Packed';
      case 2: return 'Confirm Dispatch';
      case 3: return 'Mark Delivered';
      default: return 'Complete';
    }
  }

  static const List<Map<String, dynamic>> _orderItems = [
    {'name': 'Tata Salt 1kg', 'qty': 2, 'price': '₹50'},
    {'name': 'Amul Butter 100g', 'qty': 1, 'price': '₹60'},
    {'name': 'Fortune Refined Oil 1L', 'qty': 1, 'price': '₹175'},
    {'name': 'Parle-G Biscuits 800g', 'qty': 1, 'price': '₹85'},
  ];

  static const List<Map<String, dynamic>> _deliveryBoys = [
    {'name': 'Ramesh Kumar', 'status': 'Available'},
    {'name': 'Suresh Patil', 'status': 'Available'},
    {'name': 'Anil Sharma', 'status': 'On Delivery'},
  ];
}

class _OrderItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
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
                Text(item['name'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                Text('Qty: ${item['qty']}', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
          Text(item['price'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _DeliveryBoyTile extends StatelessWidget {
  final String name;
  final String status;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryBoyTile({required this.name, required this.status, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isAvailable = status == 'Available';
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : c.card,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.primary, width: 1.5) : Border.all(color: c.divider, width: 0.5),
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
                  Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  Text(status, style: GoogleFonts.inter(fontSize: 12, color: isAvailable ? AppColors.green : c.textHint)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
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

  const _StepTile({required this.index, required this.step, required this.currentStep, required this.isLast});

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
                color: isDone ? AppColors.green : isCurrent ? AppColors.primary : c.card,
                border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : Border.all(color: c.divider, width: 1),
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
                  color: isDone ? AppColors.green : isCurrent ? c.textPrimary : c.textHint,
                ),
              ),
              Text(step['desc'] as String, style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
            ],
          ),
        ),
      ],
    );
  }
}
