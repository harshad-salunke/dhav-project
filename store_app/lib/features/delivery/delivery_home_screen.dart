import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/constants/app_routes.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  bool _isAvailable = true;

  void _toggleAvailability(bool value) {
    HapticFeedback.mediumImpact();
    setState(() => _isAvailable = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: CustomScrollView(
        slivers: [
          // App bar with profile
          SliverToBoxAdapter(child: _buildHeader(c)),

          // Availability toggle — big and prominent
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildAvailabilityCard(c),
            ),
          ),

          // Incoming assignment banner (shown when pending)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildIncomingBanner(c),
            ),
          ),

          // Today's stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildTodayStats(c),
            ),
          ),

          // Active delivery card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildActiveDelivery(c),
            ),
          ),

          // Quick actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildQuickActions(c),
            ),
          ),

          // Recent deliveries header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text("RECENT DELIVERIES", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryHistory),
                    child: Text('VIEW ALL', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
          ),

          // Recent deliveries list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _RecentDeliveryTile(data: _recentDeliveries[i]),
              ),
              childCount: _recentDeliveries.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeader(DhavColors c) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ramesh Kumar', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 13),
                    const SizedBox(width: 2),
                    Text('Kothrud Zone', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                    const SizedBox(width: 2),
                    Text('4.8', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
            child: Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
                  child: Icon(Icons.notifications_rounded, color: c.textPrimary, size: 22),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(DhavColors c) {
    return GestureDetector(
      onTap: () => _toggleAvailability(!_isAvailable),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: _isAvailable
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                )
              : null,
          color: _isAvailable ? null : c.card,
          borderRadius: BorderRadius.circular(20),
          border: _isAvailable ? null : Border.all(color: c.divider, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (_isAvailable ? Colors.white : c.iconBg).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isAvailable ? Icons.delivery_dining_rounded : Icons.do_not_disturb_rounded,
                color: _isAvailable ? Colors.white : c.textHint,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAvailable ? 'ONLINE' : 'OFFLINE',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _isAvailable ? Colors.white : c.textHint,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    _isAvailable ? 'You are accepting deliveries' : 'Tap to go online',
                    style: GoogleFonts.inter(fontSize: 12, color: _isAvailable ? Colors.white70 : c.textHint),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 1.1,
              child: Switch(
                value: _isAvailable,
                onChanged: _toggleAvailability,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.3),
                inactiveThumbColor: c.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingBanner(DhavColors c) {
    // Simulates a pending incoming assignment
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryIncomingAssignment),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Assignment Waiting!', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text('Earn ₹55 · 2.0 km · Kothrud', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: Text('VIEW', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats(DhavColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TODAY'S PERFORMANCE", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(icon: Icons.local_shipping_rounded, label: 'Deliveries', value: '8', color: AppColors.primary, c: c),
            const SizedBox(width: 10),
            _StatCard(icon: Icons.account_balance_wallet_rounded, label: 'Earned', value: '₹480', color: AppColors.green, c: c),
            const SizedBox(width: 10),
            _StatCard(icon: Icons.route_rounded, label: 'Distance', value: '12 km', color: Colors.blue, c: c),
            const SizedBox(width: 10),
            _StatCard(icon: Icons.star_rounded, label: 'Rating', value: '4.9', color: Colors.amber, c: c),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveDelivery(DhavColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACTIVE DELIVERY', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryAssignment),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Order #OD-9929', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text('IN PROGRESS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress steps
                Row(
                  children: [
                    _StepDot(label: 'At Store', done: true),
                    _StepLine(done: true),
                    _StepDot(label: 'Picked Up', done: true),
                    _StepLine(done: false),
                    _StepDot(label: 'Delivering', done: false, active: true),
                    _StepLine(done: false),
                    _StepDot(label: 'Done', done: false),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.green, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Flat 302, Laxmi Niwas, Kothrud', style: GoogleFonts.inter(fontSize: 12, color: c.textHint), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('5 min ETA', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryAssignment),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.map_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text('NAVIGATE', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.phone_rounded, color: c.textSecondary, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(DhavColors c) {
    return Row(
      children: [
        _QuickAction(
          icon: Icons.history_rounded,
          label: 'History',
          color: Colors.purple,
          c: c,
          onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryHistory),
        ),
        const SizedBox(width: 12),
        _QuickAction(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Earnings',
          color: AppColors.green,
          c: c,
          onTap: () => Navigator.pushNamed(context, AppRoutes.earnings),
        ),
        const SizedBox(width: 12),
        _QuickAction(
          icon: Icons.person_rounded,
          label: 'Profile',
          color: AppColors.primary,
          c: c,
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
        ),
        const SizedBox(width: 12),
        _QuickAction(
          icon: Icons.help_outline_rounded,
          label: 'Support',
          color: Colors.orange,
          c: c,
          onTap: () => Navigator.pushNamed(context, AppRoutes.helpSupport),
        ),
      ],
    );
  }

  static const List<Map<String, dynamic>> _recentDeliveries = [
    {'id': 'OD-9928', 'address': 'Shivaji Nagar, Pune', 'time': '14:20', 'earning': '₹60', 'status': 'Delivered', 'distance': '1.8 km'},
    {'id': 'OD-9927', 'address': 'Karve Nagar, Pune', 'time': '13:45', 'earning': '₹55', 'status': 'Delivered', 'distance': '1.4 km'},
    {'id': 'OD-9926', 'address': 'Paud Road, Kothrud', 'time': '13:10', 'earning': '₹65', 'status': 'Delivered', 'distance': '2.1 km'},
  ];
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final DhavColors c;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.c});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: c.textHint)),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;

  const _StepDot({required this.label, required this.done, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.green
        : active
            ? AppColors.primary
            : Colors.grey.shade300;

    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: done ? const Icon(Icons.check, size: 7, color: Colors.white) : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 8, color: done ? AppColors.green : active ? AppColors.primary : Colors.grey)),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 12),
        color: done ? AppColors.green : Colors.grey.shade300,
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final DhavColors c;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentDeliveryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecentDeliveryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.greenBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${data['id']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text(data['address'] as String, style: GoogleFonts.inter(fontSize: 11, color: c.textHint), overflow: TextOverflow.ellipsis),
                Text('${data['time']} · ${data['distance']}', style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
              ],
            ),
          ),
          Text(data['earning'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.green)),
        ],
      ),
    );
  }
}
