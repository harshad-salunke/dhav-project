import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_sidebar.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/providers/stores_provider.dart';
import '../../core/models/store.dart';
import '../../core/models/catalog_item.dart';
import '../../core/services/api_client.dart';
import '../../core/constants/app_routes.dart';

class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final ApiClient _api = ApiClient();

  AdminStore? _store;
  StoreStats? _stats;
  List<StoreInventoryItem> _inventory = [];
  List<StoreReview> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sid = widget.storeId;
      final results = await Future.wait([
        _api.get('/admin/stores/$sid'),
        _api.get('/admin/stores/$sid/stats'),
        _api.get('/admin/stores/$sid/inventory'),
        _api.get('/admin/stores/$sid/reviews'),
      ]);

      _store = AdminStore.fromJson(results[0] as Map<String, dynamic>);
      _stats = StoreStats.fromJson(results[1] as Map<String, dynamic>);
      _inventory = (results[2]['items'] as List)
          .map((i) => StoreInventoryItem.fromJson(i as Map<String, dynamic>))
          .toList();
      _reviews = (results[3]['reviews'] as List)
          .map((r) => StoreReview.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          const AdminSidebar(),
          const VerticalDivider(color: AppColors.border, width: 1),
          Expanded(
            child: _loading
                ? _buildShimmer()
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _loadAll)
                    : _StoreDetailBody(
                        store: _store!,
                        stats: _stats!,
                        inventory: _inventory,
                        reviews: _reviews,
                        tabs: _tabs,
                        api: _api,
                        onRefresh: _loadAll,
                        storeId: widget.storeId,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header shimmer
            Container(
                height: 28,
                width: 220,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 8),
            Container(
                height: 14,
                width: 160,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 32),
            // KPI row shimmer
            Row(
              children: List.generate(
                5,
                (_) => Expanded(
                  child: Container(
                    height: 90,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 260,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StoreDetailBody extends StatelessWidget {
  final AdminStore store;
  final StoreStats stats;
  final List<StoreInventoryItem> inventory;
  final List<StoreReview> reviews;
  final TabController tabs;
  final ApiClient api;
  final VoidCallback onRefresh;
  final String storeId;

  const _StoreDetailBody({
    required this.store,
    required this.stats,
    required this.inventory,
    required this.reviews,
    required this.tabs,
    required this.api,
    required this.onRefresh,
    required this.storeId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              _OverviewTab(
                store: store,
                stats: stats,
                api: api,
                onRefresh: onRefresh,
                storeId: storeId,
              ),
              _OrdersTab(orders: stats.recentOrders),
              _InventoryTab(
                inventory: inventory,
                storeId: storeId,
                api: api,
                onRefresh: onRefresh,
              ),
              _ReviewsTab(
                reviews: reviews,
                storeId: storeId,
                api: api,
                onRefresh: onRefresh,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isActive = store.isActive && !store.isSuspended;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF374151), const Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                // Back button
                _IconBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pushReplacementNamed(
                      context, AppRoutes.stores),
                ),
                const SizedBox(width: 14),
                // Store icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Center(
                    child: Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              store.name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge.forStoreStatus(store.statusLabel),
                          if (store.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFF4ADE80), size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.6)),
                          const SizedBox(width: 3),
                          Text(
                            '${store.area}  •  ${store.phone}',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _IconBtn(
                  icon: Icons.refresh_rounded,
                  onTap: onRefresh,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tab bar
          TabBar(
            controller: tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
            indicatorColor: AppColors.orange,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Orders'),
              Tab(text: 'Inventory'),
              Tab(text: 'Reviews'),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Overview Tab ───────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  final AdminStore store;
  final StoreStats stats;
  final ApiClient api;
  final VoidCallback onRefresh;
  final String storeId;

  const _OverviewTab({
    required this.store,
    required this.stats,
    required this.api,
    required this.onRefresh,
    required this.storeId,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _editMode = false;
  final _nameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  void _resetForm() {
    _nameCtrl.text = widget.store.name;
    _areaCtrl.text = widget.store.area;
    _phoneCtrl.text = widget.store.phone;
    _addressCtrl.text = '';
    _latCtrl.text = widget.store.lat?.toStringAsFixed(6) ?? '';
    _lngCtrl.text = widget.store.lng?.toStringAsFixed(6) ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI row
          Row(
            children: [
              _KpiCard('Total Orders', s.totalOrders.toString(),
                  Icons.receipt_long_rounded, AppColors.orange,
                  sub: 'all time'),
              const SizedBox(width: 12),
              _KpiCard('Delivered', s.deliveredOrders.toString(),
                  Icons.check_circle_rounded, AppColors.green,
                  sub: 'completed'),
              const SizedBox(width: 12),
              _KpiCard('Failed', s.failedOrders.toString(),
                  Icons.cancel_rounded, AppColors.red,
                  sub: 'cancelled'),
              const SizedBox(width: 12),
              _KpiCard(
                  'Success Rate',
                  '${s.successRatePct.toStringAsFixed(1)}%',
                  Icons.trending_up_rounded,
                  AppColors.yellow,
                  sub: 'delivery rate'),
              const SizedBox(width: 12),
              _KpiCard('Revenue', '₹${_fmt(s.totalRevenue)}',
                  Icons.currency_rupee_rounded, AppColors.green,
                  sub: 'total earned'),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SectionCard(
                  title: 'Store Information',
                  trailing: TextButton.icon(
                    onPressed: () =>
                        setState(() => _editMode = !_editMode),
                    icon: Icon(
                      _editMode ? Icons.close_rounded : Icons.edit_rounded,
                      size: 14,
                    ),
                    label: Text(_editMode ? 'Cancel' : 'Edit'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.orange),
                  ),
                  child: _editMode
                      ? _EditForm(
                          nameCtrl: _nameCtrl,
                          areaCtrl: _areaCtrl,
                          phoneCtrl: _phoneCtrl,
                          addressCtrl: _addressCtrl,
                          latCtrl: _latCtrl,
                          lngCtrl: _lngCtrl,
                          saving: _saving,
                          onSave: _saveEdit,
                        )
                      : _StoreInfoView(store: widget.store),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 280,
                child: _SectionCard(
                  title: 'Admin Actions',
                  child: Consumer<StoresProvider>(
                    builder: (context, provider, _) => Column(
                      children: [
                        if (!widget.store.isVerified)
                          _AdminActionBtn(
                            label: 'Verify Store',
                            icon: Icons.verified_rounded,
                            color: AppColors.green,
                            description: 'Mark this store as verified',
                            onTap: () async {
                              await provider.verifyStore(widget.storeId);
                              widget.onRefresh();
                            },
                          ),
                        if (!widget.store.isSuspended)
                          _AdminActionBtn(
                            label: 'Suspend Store',
                            icon: Icons.block_rounded,
                            color: AppColors.red,
                            description: 'Temporarily disable this store',
                            onTap: () =>
                                _showSuspendDialog(context, provider),
                          )
                        else
                          _AdminActionBtn(
                            label: 'Unsuspend Store',
                            icon: Icons.lock_open_rounded,
                            color: AppColors.green,
                            description: 'Re-enable this store',
                            onTap: () async {
                              await provider.unsuspendStore(widget.storeId);
                              widget.onRefresh();
                            },
                          ),
                        const SizedBox(height: 4),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 4),
                        _AdminActionBtn(
                          label: 'Delete Store',
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.red,
                          description: 'Permanently remove this store',
                          onTap: () => _confirmDelete(context, provider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Future<void> _saveEdit() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };
      if (_addressCtrl.text.isNotEmpty)
        body['address'] = _addressCtrl.text.trim();
      final lat = double.tryParse(_latCtrl.text);
      final lng = double.tryParse(_lngCtrl.text);
      if (lat != null && lng != null) {
        body['lat'] = lat;
        body['lng'] = lng;
      }
      await widget.api.put('/admin/stores/${widget.storeId}', body: body);
      widget.onRefresh();
      if (mounted) setState(() => _editMode = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuspendDialog(BuildContext context, StoresProvider provider) {
    int days = 7;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Suspend Store',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How many days?',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              Row(
                children: [3, 7, 14, 30]
                    .map((d) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$d d'),
                            selected: days == d,
                            onSelected: (_) => setS(() => days = d),
                            selectedColor: AppColors.orange,
                            labelStyle: GoogleFonts.inter(
                              color: days == d
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            backgroundColor: AppColors.card,
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style:
                      GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await provider.suspendStore(widget.storeId, days);
                widget.onRefresh();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Suspend'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, StoresProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Store?',
            style: GoogleFonts.inter(
                color: AppColors.red, fontWeight: FontWeight.w700)),
        content: Text(
          'This will deactivate the store and remove it from delivery coverage. This action cannot be undone.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.deleteStore(widget.storeId);
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.stores);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── KPI Card ───────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;

  const _KpiCard(this.label, this.value, this.icon, this.color,
      {this.sub = ''});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 11)),
            if (sub.isNotEmpty)
              Text(sub,
                  style: GoogleFonts.inter(
                      color: color.withValues(alpha: 0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Section Card ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard(
      {required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Store info view ────────────────────────────────────────────────────────────

class _StoreInfoView extends StatelessWidget {
  final AdminStore store;
  const _StoreInfoView({required this.store});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow('Owner', store.ownerName),
        _InfoRow('Phone', store.phone),
        _InfoRow('Area', store.area),
        _InfoRow('Strikes', store.strikeCount.toString()),
        if (store.lat != null && store.lng != null)
          _InfoRow('Location',
              '${store.lat!.toStringAsFixed(5)}, ${store.lng!.toStringAsFixed(5)}'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Edit form ──────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final TextEditingController nameCtrl,
      areaCtrl,
      phoneCtrl,
      addressCtrl,
      latCtrl,
      lngCtrl;
  final bool saving;
  final VoidCallback onSave;

  const _EditForm({
    required this.nameCtrl,
    required this.areaCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.latCtrl,
    required this.lngCtrl,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EditField('Store Name', nameCtrl),
        const SizedBox(height: 10),
        _EditField('Area', areaCtrl),
        const SizedBox(height: 10),
        _EditField('Phone', phoneCtrl),
        const SizedBox(height: 10),
        _EditField('Address (optional)', addressCtrl),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _EditField('Latitude', latCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _EditField('Longitude', lngCtrl)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes'),
          ),
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _EditField(this.label, this.ctrl);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style:
          GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      ),
    );
  }
}

// ── Admin action button ────────────────────────────────────────────────────────

class _AdminActionBtn extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.description = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (description.isNotEmpty)
                      Text(description,
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Orders Tab ─────────────────────────────────────────────────────────────────

class _OrdersTab extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _OrdersTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.orange, size: 28),
            ),
            const SizedBox(height: 14),
            Text('No orders yet',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Orders will appear here once placed',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            _OrdersHeader(),
            const Divider(color: AppColors.border, height: 1),
            ...orders.map((o) => _OrderRow(order: o)),
          ],
        ),
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('ORDER ID', style: style)),
          Expanded(child: Text('STATUS', style: style)),
          Expanded(child: Text('AMOUNT', style: style)),
          Expanded(flex: 2, child: Text('DATE', style: style)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'unknown';
    final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final ts = order['created_at'];
    final date = ts != null
        ? DateFormat('dd MMM yy, hh:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(ts as int))
        : '—';
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                (order['order_id'] ?? '').toString().substring(0, 8) + '…',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            Expanded(child: StatusBadge.forOrderStatus(status)),
            Expanded(
              child: Text('₹${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              flex: 2,
              child: Text(date,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inventory Tab ──────────────────────────────────────────────────────────────

class _InventoryTab extends StatefulWidget {
  final List<StoreInventoryItem> inventory;
  final String storeId;
  final ApiClient api;
  final VoidCallback onRefresh;

  const _InventoryTab({
    required this.inventory,
    required this.storeId,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  late List<StoreInventoryItem> _items;
  String _search = '';
  String? _filterCat;
  // Show only items the store has marked available (is_available = true)
  bool _showOnlyAvailable = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.inventory);
  }

  List<String> get _categories {
    final cats = _items
        .where((i) => !_showOnlyAvailable || i.isAvailable)
        .map((i) => i.category)
        .toSet()
        .toList()
      ..sort();
    return cats;
  }

  List<StoreInventoryItem> get _filtered {
    return _items.where((item) {
      if (_showOnlyAvailable && !item.isAvailable) return false;
      final matchSearch = _search.isEmpty ||
          item.name.toLowerCase().contains(_search.toLowerCase());
      final matchCat = _filterCat == null || item.category == _filterCat;
      return matchSearch && matchCat;
    }).toList();
  }

  void _showAddFromCatalog() {
    showDialog(
      context: context,
      builder: (_) => _AddFromCatalogDialog(
        existingItemIds: _items.map((i) => i.itemId).toSet(),
        api: widget.api,
        onAdd: (newItems) {
          setState(() => _items.insertAll(0, newItems));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              '${newItems.length} item${newItems.length == 1 ? '' : 's'} added — press Save to persist',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: AppColors.orange,
          ));
        },
      ),
    );
  }

  Future<void> _saveInventory() async {
    setState(() => _saving = true);
    try {
      await widget.api.put(
        '/admin/stores/${widget.storeId}/inventory',
        body: {'items': _items.map((i) => i.toPayload()).toList()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Inventory saved!',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final availableCount = _items.where((i) => i.isAvailable).length;

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              // Availability stats
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: AppColors.green),
                    const SizedBox(width: 6),
                    Text(
                      '$availableCount of ${_items.length} available',
                      style: GoogleFonts.inter(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Show only available toggle
              _FilterToggle(
                label: 'Available only',
                value: _showOnlyAvailable,
                onChanged: (v) => setState(() {
                  _showOnlyAvailable = v;
                  _filterCat = null;
                }),
              ),
              const Spacer(),
              // Search
              SizedBox(
                width: 200,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search items…',
                    hintStyle: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textMuted, size: 16),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.orange, width: 1.5)),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showAddFromCatalog,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Add from Catalog'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveInventory,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 15),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        // Category filter chips
        if (_categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CatChip(
                    label: 'All',
                    active: _filterCat == null,
                    onTap: () => setState(() => _filterCat = null),
                  ),
                  ..._categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _CatChip(
                          label: cat,
                          active: _filterCat == cat,
                          onTap: () => setState(() =>
                              _filterCat = _filterCat == cat ? null : cat),
                        ),
                      )),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        // Items
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          color: AppColors.textMuted, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        _showOnlyAvailable
                            ? 'No available items'
                            : 'No items found',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 14),
                      ),
                      if (_showOnlyAvailable)
                        TextButton(
                          onPressed: () =>
                              setState(() => _showOnlyAvailable = false),
                          child: const Text('Show all items'),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    return _InventoryItemRow(
                      item: item,
                      onToggle: (val) =>
                          setState(() => item.isAvailable = val),
                      onQtyChange: (val) =>
                          setState(() => item.quantity = val),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value
              ? AppColors.orange.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: value ? AppColors.orange : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_off_rounded,
              size: 14,
              color: value ? AppColors.orange : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: value ? AppColors.orange : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CatChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.orange : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? AppColors.orange : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
              color: active ? Colors.white : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _InventoryItemRow extends StatelessWidget {
  final StoreInventoryItem item;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onQtyChange;

  const _InventoryItemRow(
      {required this.item,
      required this.onToggle,
      required this.onQtyChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isAvailable
              ? AppColors.green.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Switch(
            value: item.isAvailable,
            onChanged: onToggle,
            activeThumbColor: AppColors.green,
            activeTrackColor: AppColors.green.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.inter(
                      color: item.isAvailable
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                Text('${item.category} • ${item.unit}',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          if (item.isAvailable) ...[
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded,
                  color: AppColors.textSecondary, size: 20),
              onPressed: () {
                if (item.quantity > 0) onQtyChange(item.quantity - 1);
              },
              splashRadius: 16,
            ),
            SizedBox(
              width: 36,
              child: Text(item.quantity.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.orange, size: 20),
              onPressed: () => onQtyChange(item.quantity + 1),
              splashRadius: 16,
            ),
          ] else
            const SizedBox(width: 100),
        ],
      ),
    );
  }
}

// ── Reviews Tab ────────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  final List<StoreReview> reviews;
  final String storeId;
  final ApiClient api;
  final VoidCallback onRefresh;

  const _ReviewsTab({
    required this.reviews,
    required this.storeId,
    required this.api,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.star_outline_rounded,
                  color: AppColors.yellow, size: 28),
            ),
            const SizedBox(height: 14),
            Text('No reviews yet',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Reviews will appear here after deliveries',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        reviews.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      height: 1),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                                i < avg.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: AppColors.yellow,
                                size: 22,
                              )),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...reviews.map((r) => _ReviewCard(
                review: r,
                storeId: storeId,
                api: api,
                onRefresh: onRefresh,
              )),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final StoreReview review;
  final String storeId;
  final ApiClient api;
  final VoidCallback onRefresh;

  const _ReviewCard(
      {required this.review,
      required this.storeId,
      required this.api,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(
        DateTime.fromMillisecondsSinceEpoch(review.createdAt));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                child: Text(
                  review.customerName.isNotEmpty
                      ? review.customerName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.inter(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.customerName,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(date,
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < review.rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.yellow,
                          size: 15,
                        )),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _confirmDelete(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppColors.red.withValues(alpha: 0.7),
                      size: 16),
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.comment,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Review?',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text('This review will be permanently removed.',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style:
                    GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await api.delete(
                    '/admin/stores/$storeId/reviews/${review.reviewId}');
                onRefresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed: $e',
                        style: GoogleFonts.inter(color: Colors.white)),
                    backgroundColor: AppColors.red,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Add from Catalog Dialog ────────────────────────────────────────────────────

class _AddFromCatalogDialog extends StatefulWidget {
  final Set<String> existingItemIds;
  final ApiClient api;
  final ValueChanged<List<StoreInventoryItem>> onAdd;

  const _AddFromCatalogDialog({
    required this.existingItemIds,
    required this.api,
    required this.onAdd,
  });

  @override
  State<_AddFromCatalogDialog> createState() => _AddFromCatalogDialogState();
}

class _AddFromCatalogDialogState extends State<_AddFromCatalogDialog> {
  List<AdminCatalogItem> _catalogItems = [];
  bool _loading = true;
  String? _loadError;
  String _search = '';
  String? _filterCat;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final data = await widget.api.get('/admin/catalog/items');
      final all = (data['items'] as List)
          .map((i) => AdminCatalogItem.fromJson(i as Map<String, dynamic>))
          .where((i) => i.isActive && !widget.existingItemIds.contains(i.itemId))
          .toList();
      if (mounted) setState(() { _catalogItems = all; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  List<String> get _categories {
    final cats = _catalogItems.map((i) => i.category).toSet().toList()..sort();
    return cats;
  }

  List<AdminCatalogItem> get _filtered {
    return _catalogItems.where((item) {
      final matchSearch = _search.isEmpty ||
          item.name.toLowerCase().contains(_search.toLowerCase());
      final matchCat = _filterCat == null || item.category == _filterCat;
      return matchSearch && matchCat;
    }).toList();
  }

  void _confirm() {
    final newItems = _catalogItems
        .where((i) => _selected.contains(i.itemId))
        .map((i) => StoreInventoryItem(
              itemId: i.itemId,
              name: i.name,
              category: i.category,
              unit: i.unit,
              isAvailable: true,
              quantity: 1,
            ))
        .toList();
    widget.onAdd(newItems);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 560,
        height: 620,
        child: Column(
          children: [
            // ── Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add from Catalog',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // ── Search + Category chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search catalog items…',
                      hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textMuted, size: 16),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.orange, width: 1.5)),
                    ),
                  ),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CatChip(
                            label: 'All',
                            active: _filterCat == null,
                            onTap: () => setState(() => _filterCat = null),
                          ),
                          ..._categories.map((cat) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _CatChip(
                                  label: cat,
                                  active: _filterCat == cat,
                                  onTap: () => setState(() =>
                                      _filterCat = _filterCat == cat ? null : cat),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Item list
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.orange))
                  : _loadError != null
                      ? Center(
                          child: Text(_loadError!,
                              style: GoogleFonts.inter(
                                  color: AppColors.red, fontSize: 12)))
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined,
                                      color: AppColors.textMuted, size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    _search.isNotEmpty
                                        ? 'No items match "$_search"'
                                        : 'All catalog items already added',
                                    style: GoogleFonts.inter(
                                        color: AppColors.textMuted,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final item = filtered[i];
                                final isSel =
                                    _selected.contains(item.itemId);
                                return InkWell(
                                  onTap: () => setState(() => isSel
                                      ? _selected.remove(item.itemId)
                                      : _selected.add(item.itemId)),
                                  borderRadius: BorderRadius.circular(8),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(top: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? AppColors.orange
                                              .withValues(alpha: 0.08)
                                          : AppColors.card,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSel
                                            ? AppColors.orange
                                                .withValues(alpha: 0.5)
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: isSel,
                                            onChanged: (v) => setState(() =>
                                                v == true
                                                    ? _selected
                                                        .add(item.itemId)
                                                    : _selected.remove(
                                                        item.itemId)),
                                            activeColor: AppColors.orange,
                                            side: const BorderSide(
                                                color: AppColors.border,
                                                width: 1.5),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: GoogleFonts.inter(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                              Text(
                                                '${item.category} · ${item.unit}',
                                                style: GoogleFonts.inter(
                                                    color:
                                                        AppColors.textMuted,
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSel)
                                          const Icon(
                                              Icons.check_circle_rounded,
                                              color: AppColors.orange,
                                              size: 16),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            // ── Footer
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Text(
                    _selected.isEmpty
                        ? 'Select items to add'
                        : '${_selected.length} item${_selected.length == 1 ? '' : 's'} selected',
                    style: GoogleFonts.inter(
                        color: _selected.isEmpty
                            ? AppColors.textMuted
                            : AppColors.orange,
                        fontSize: 12,
                        fontWeight: _selected.isEmpty
                            ? FontWeight.normal
                            : FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selected.isEmpty ? null : _confirm,
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: Text(_selected.isEmpty
                        ? 'Add Items'
                        : 'Add ${_selected.length}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      disabledForegroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error View ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AppColors.red, size: 28),
          ),
          const SizedBox(height: 14),
          Text('Failed to load store',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(error,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
