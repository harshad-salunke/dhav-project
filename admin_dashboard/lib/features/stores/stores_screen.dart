import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/stores_provider.dart';
import '../../core/models/store.dart';
import '../../core/widgets/admin_sidebar.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/constants/app_routes.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoresProvider>().loadStores();
    });
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
            child: Consumer<StoresProvider>(
              builder: (context, provider, _) {
                final filtered = provider.stores
                    .where((s) =>
                        s.name.toLowerCase().contains(_search.toLowerCase()) ||
                        s.area.toLowerCase().contains(_search.toLowerCase()) ||
                        s.ownerName
                            .toLowerCase()
                            .contains(_search.toLowerCase()))
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StoresHeader(
                      total: provider.stores.length,
                      onSearch: (v) => setState(() => _search = v),
                      provider: provider,
                    ),
                    Expanded(
                      child: provider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.orange))
                          : _StoresTable(stores: filtered, provider: provider),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoresHeader extends StatelessWidget {
  final int total;
  final ValueChanged<String> onSearch;
  final StoresProvider provider;

  const _StoresHeader(
      {required this.total,
      required this.onSearch,
      required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stores',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              Text('$total stores registered',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const Spacer(),
          // Filters
          _FilterChip(
              label: 'All',
              active: provider.filterSuspended == null &&
                  provider.filterActive == null,
              onTap: () => provider.setFilter()),
          const SizedBox(width: 8),
          _FilterChip(
              label: 'Online',
              active: provider.filterActive == true,
              onTap: () => provider.setFilter(active: true)),
          const SizedBox(width: 8),
          _FilterChip(
              label: 'Suspended',
              active: provider.filterSuspended == true,
              onTap: () => provider.setFilter(suspended: true)),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: onSearch,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search stores...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 16),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Onboard new store button
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.storeOnboard),
            icon: const Icon(Icons.add_business_rounded, size: 16),
            label: const Text('Onboard Store'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.orange : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? AppColors.orange : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: active ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _StoresTable extends StatelessWidget {
  final List<AdminStore> stores;
  final StoresProvider provider;
  const _StoresTable({required this.stores, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return Center(
          child: Text('No stores found',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 14)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _TableHeader(),
            const Divider(color: AppColors.border, height: 1),
            ...stores
                .map((s) => _StoreRow(store: s, provider: provider)),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('STORE', style: style)),
          Expanded(flex: 2, child: Text('OWNER', style: style)),
          Expanded(child: Text('STATUS', style: style)),
          Expanded(child: Text('STRIKES', style: style)),
          Expanded(child: Text('VERIFIED', style: style)),
          SizedBox(width: 160, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final AdminStore store;
  final StoresProvider provider;
  const _StoreRow({required this.store, required this.provider});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.storeDetail,
        arguments: store.storeId,
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Store name + area
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(store.area,
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              // Owner
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.ownerName,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary, fontSize: 12)),
                    Text(store.phone,
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              // Status
              Expanded(
                  child: StatusBadge.forStoreStatus(store.statusLabel)),
              // Strikes
              Expanded(
                child: Row(
                  children: [
                    if (store.strikeCount > 0) ...[
                      Icon(Icons.warning_amber_rounded,
                          color: store.strikeCount >= 3
                              ? AppColors.red
                              : AppColors.yellow,
                          size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(store.strikeCount.toString(),
                        style: GoogleFonts.inter(
                            color: store.strikeCount >= 3
                                ? AppColors.red
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              // Verified
              Expanded(
                child: Icon(
                  store.isVerified
                      ? Icons.verified_rounded
                      : Icons.pending_rounded,
                  color: store.isVerified
                      ? AppColors.green
                      : AppColors.textMuted,
                  size: 18,
                ),
              ),
              // Actions
              SizedBox(
                width: 160,
                child: Row(
                  children: [
                    // View Details
                    _ActionBtn(
                      icon: Icons.open_in_new_rounded,
                      color: AppColors.orange,
                      tooltip: 'View Details',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.storeDetail,
                        arguments: store.storeId,
                      ),
                    ),
                    if (!store.isVerified)
                      _ActionBtn(
                        icon: Icons.verified_rounded,
                        color: AppColors.green,
                        tooltip: 'Verify',
                        onTap: () => _confirm(
                            context,
                            'Verify ${store.name}?',
                            'This will allow the store to receive orders.',
                            () => provider.verifyStore(store.storeId)),
                      ),
                    if (!store.isSuspended)
                      _ActionBtn(
                        icon: Icons.block_rounded,
                        color: AppColors.red,
                        tooltip: 'Suspend',
                        onTap: () =>
                            _showSuspendDialog(context, store),
                      )
                    else
                      _ActionBtn(
                        icon: Icons.lock_open_rounded,
                        color: AppColors.green,
                        tooltip: 'Unsuspend',
                        onTap: () => _confirm(
                            context,
                            'Unsuspend ${store.name}?',
                            'Store will be reinstated and can receive orders again.',
                            () => provider.unsuspendStore(store.storeId)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm(BuildContext context, String title, String msg,
      Future<bool> Function() action) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title,
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
        content: Text(msg,
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await action();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSuspendDialog(BuildContext context, AdminStore store) {
    int days = 7;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: Text('Suspend ${store.name}',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How many days should the store be suspended?',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final d in [3, 7, 14, 30])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$d days'),
                        selected: days == d,
                        onSelected: (_) => setS(() => days = d),
                        selectedColor: AppColors.orange,
                        labelStyle: GoogleFonts.inter(
                            color: days == d
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 12),
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await provider.suspendStore(store.storeId, days);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red),
              child: const Text('Suspend'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onTap,
        splashRadius: 18,
      ),
    );
  }
}
