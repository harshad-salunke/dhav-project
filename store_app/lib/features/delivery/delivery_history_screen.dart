import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Text('Delivery History', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.primary,
              unselectedLabelColor: c.textHint,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'This Week'),
                Tab(text: 'All Time'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Summary card
          Padding(
            padding: const EdgeInsets.all(16),
            child: _SummaryCard(tabController: _tabController),
          ),

          // Delivery list per tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DeliveryList(deliveries: _todayDeliveries),
                _DeliveryList(deliveries: _weekDeliveries),
                _DeliveryList(deliveries: _allDeliveries),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final List<Map<String, dynamic>> _todayDeliveries = [
    {'id': 'OD-9929', 'address': 'Flat 302, Laxmi Niwas, Kothrud', 'time': '15:10', 'earning': '₹55', 'status': 'Delivered', 'items': 3, 'distance': '2.0 km'},
    {'id': 'OD-9928', 'address': 'Shivaji Nagar, Pune', 'time': '14:20', 'earning': '₹60', 'status': 'Delivered', 'items': 4, 'distance': '1.8 km'},
    {'id': 'OD-9927', 'address': 'Karve Nagar, Pune', 'time': '13:45', 'earning': '₹55', 'status': 'Delivered', 'items': 2, 'distance': '1.4 km'},
    {'id': 'OD-9926', 'address': 'Paud Road, Kothrud', 'time': '13:10', 'earning': '₹65', 'status': 'Delivered', 'items': 5, 'distance': '2.1 km'},
    {'id': 'OD-9925', 'address': 'Erandwane, Pune', 'time': '12:30', 'earning': '₹0', 'status': 'Failed', 'items': 1, 'distance': '1.2 km'},
    {'id': 'OD-9924', 'address': 'Model Colony, Pune', 'time': '11:55', 'earning': '₹50', 'status': 'Delivered', 'items': 2, 'distance': '0.9 km'},
    {'id': 'OD-9923', 'address': 'Deccan, Pune', 'time': '11:10', 'earning': '₹70', 'status': 'Delivered', 'items': 6, 'distance': '2.4 km'},
    {'id': 'OD-9922', 'address': 'Bavdhan, Pune', 'time': '10:30', 'earning': '₹60', 'status': 'Delivered', 'items': 3, 'distance': '1.9 km'},
    {'id': 'OD-9921', 'address': 'Warje, Pune', 'time': '09:50', 'earning': '₹65', 'status': 'Delivered', 'items': 4, 'distance': '2.2 km'},
  ];

  static final List<Map<String, dynamic>> _weekDeliveries = [
    ..._todayDeliveries,
    {'id': 'OD-9920', 'address': 'Kothrud, Pune', 'time': 'Yesterday', 'earning': '₹55', 'status': 'Delivered', 'items': 2, 'distance': '1.1 km'},
    {'id': 'OD-9919', 'address': 'Sinhagad Road, Pune', 'time': 'Yesterday', 'earning': '₹70', 'status': 'Delivered', 'items': 5, 'distance': '2.3 km'},
    {'id': 'OD-9918', 'address': 'Narayan Peth, Pune', 'time': 'Yesterday', 'earning': '₹0', 'status': 'Failed', 'items': 1, 'distance': '0.8 km'},
    {'id': 'OD-9917', 'address': 'Pune Station Area', 'time': '2 days ago', 'earning': '₹60', 'status': 'Delivered', 'items': 3, 'distance': '1.6 km'},
  ];

  static final List<Map<String, dynamic>> _allDeliveries = [
    ..._weekDeliveries,
    {'id': 'OD-9900', 'address': 'Aundh, Pune', 'time': 'Last week', 'earning': '₹55', 'status': 'Delivered', 'items': 2, 'distance': '1.3 km'},
    {'id': 'OD-9899', 'address': 'Baner, Pune', 'time': 'Last week', 'earning': '₹65', 'status': 'Delivered', 'items': 4, 'distance': '1.9 km'},
    {'id': 'OD-9898', 'address': 'Hinjewadi, Pune', 'time': 'Last week', 'earning': '₹80', 'status': 'Delivered', 'items': 6, 'distance': '3.1 km'},
  ];
}

// ─── Summary card that adapts to current tab ─────────────────────────────────

class _SummaryCard extends StatefulWidget {
  final TabController tabController;
  const _SummaryCard({required this.tabController});

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  static const _summaries = [
    {'deliveries': '8', 'failed': '1', 'earned': '₹480', 'distance': '14.0 km', 'rating': '4.9'},
    {'deliveries': '43', 'failed': '2', 'earned': '₹2,780', 'distance': '72.4 km', 'rating': '4.8'},
    {'deliveries': '118', 'failed': '5', 'earned': '₹7,080', 'distance': '198 km', 'rating': '4.8'},
  ];

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.tabController.index;
    final s = _summaries[idx];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                ['TODAY', 'THIS WEEK', 'ALL TIME'][idx],
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryMetric(label: 'Deliveries', value: s['deliveries']!),
              _SummaryMetric(label: 'Earned', value: s['earned']!),
              _SummaryMetric(label: 'Distance', value: s['distance']!),
              _SummaryMetric(label: 'Rating', value: '${s['rating']!} ★'),
            ],
          ),
          if (s['failed'] != '0') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text('${s['failed']} failed deliveries', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
      ],
    );
  }
}

// ─── Delivery list ────────────────────────────────────────────────────────────

class _DeliveryList extends StatelessWidget {
  final List<Map<String, dynamic>> deliveries;
  const _DeliveryList({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    if (deliveries.isEmpty) {
      return Center(child: Text('No deliveries', style: GoogleFonts.inter(color: context.colors.textHint)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: deliveries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _HistoryCard(data: deliveries[i]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HistoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDelivered = data['status'] == 'Delivered';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDelivered ? c.greenBg : c.redBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDelivered ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isDelivered ? AppColors.green : AppColors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${data['id']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 3),
                Text(data['address'] as String, style: GoogleFonts.inter(fontSize: 12, color: c.textHint), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 11, color: c.textHint),
                    const SizedBox(width: 3),
                    Text(data['time'] as String, style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
                    const SizedBox(width: 8),
                    Icon(Icons.straighten_rounded, size: 11, color: c.textHint),
                    const SizedBox(width: 3),
                    Text(data['distance'] as String, style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
                    const SizedBox(width: 8),
                    Icon(Icons.shopping_bag_outlined, size: 11, color: c.textHint),
                    const SizedBox(width: 3),
                    Text('${data['items']} items', style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data['earning'] as String,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDelivered ? AppColors.green : c.textHint),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDelivered ? c.greenBg : c.redBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data['status'] as String,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isDelivered ? AppColors.green : AppColors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
