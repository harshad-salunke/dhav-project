import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/settlements_provider.dart';
import '../../core/models/settlement.dart';
import '../../core/widgets/admin_sidebar.dart';
import '../../core/widgets/status_badge.dart';

class SettlementsScreen extends StatefulWidget {
  const SettlementsScreen({super.key});

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  String? _statusFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettlementsProvider>().loadSettlements();
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
            child: Consumer<SettlementsProvider>(
              builder: (context, provider, _) {
                final filtered = provider.settlements
                    .where((s) =>
                        s.storeName
                            .toLowerCase()
                            .contains(_search.toLowerCase()))
                    .toList();

                // Summary stats
                final totalOwed = provider.settlements.fold<double>(
                    0, (sum, s) => sum + (s.status == 'pending' ? s.totalFeeOwed : 0));
                final overdueCount =
                    provider.settlements.where((s) => s.isOverdue).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettlementsHeader(
                      total: provider.settlements.length,
                      statusFilter: _statusFilter,
                      onSearch: (v) => setState(() => _search = v),
                      onStatusChange: (s) {
                        setState(() => _statusFilter = s);
                        provider.loadSettlements(status: s);
                      },
                      onRefresh: () => provider.loadSettlements(status: _statusFilter),
                    ),
                    // Summary bar
                    if (!provider.isLoading) ...[
                      _SummaryBar(
                          totalOwed: totalOwed, overdueCount: overdueCount),
                    ],
                    Expanded(
                      child: provider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.orange))
                          : _SettlementsTable(
                              settlements: filtered, provider: provider),
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

class _SettlementsHeader extends StatelessWidget {
  final int total;
  final String? statusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatusChange;
  final VoidCallback onRefresh;

  const _SettlementsHeader({
    required this.total,
    required this.statusFilter,
    required this.onSearch,
    required this.onStatusChange,
    required this.onRefresh,
  });

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
              Text('Settlements',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              Text('$total records',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const Spacer(),
          // Filter chips
          for (final s in [null, 'pending', 'paid'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onStatusChange(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusFilter == s
                        ? AppColors.orange
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusFilter == s
                            ? AppColors.orange
                            : AppColors.border),
                  ),
                  child: Text(s ?? 'All',
                      style: GoogleFonts.inter(
                          color: statusFilter == s
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          const SizedBox(width: 8),
          SizedBox(
            width: 200,
            child: TextField(
              onChanged: onSearch,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search store...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 16),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final double totalOwed;
  final int overdueCount;
  const _SummaryBar({required this.totalOwed, required this.overdueCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _SummaryItem(
            icon: Icons.pending_rounded,
            iconColor: AppColors.yellow,
            label: 'Pending to Collect',
            value: '₹${totalOwed.toStringAsFixed(0)}',
          ),
          Container(width: 1, height: 40, color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 24)),
          _SummaryItem(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.red,
            label: 'Overdue Stores',
            value: overdueCount.toString(),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _SummaryItem(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 11)),
            Text(value,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _SettlementsTable extends StatelessWidget {
  final List<AdminSettlement> settlements;
  final SettlementsProvider provider;
  const _SettlementsTable(
      {required this.settlements, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (settlements.isEmpty) {
      return Center(
          child: Text('No settlements found',
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
            ...settlements
                .map((s) => _SettlementRow(s: s, provider: provider)),
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
        children: const [
          Expanded(flex: 3, child: Text('STORE', style: style)),
          Expanded(flex: 2, child: Text('WEEK', style: style)),
          Expanded(child: Text('ORDERS', style: style)),
          Expanded(child: Text('FEE OWED', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(width: 100, child: Text('ACTION', style: style)),
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  final AdminSettlement s;
  final SettlementsProvider provider;
  const _SettlementRow({required this.s, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  if (s.isOverdue) ...[
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.red, size: 14),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(s.storeName,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('${s.weekStart} – ${s.weekEnd}',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 11)),
            ),
            Expanded(
              child: Text(s.deliveredOrderCount.toString(),
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 12)),
            ),
            Expanded(
              child: Text('₹${s.totalFeeOwed.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      color: s.isOverdue
                          ? AppColors.red
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 2,
              child: s.status == 'paid'
                  ? StatusBadge.green('Paid')
                  : s.isOverdue
                      ? StatusBadge.red('Overdue')
                      : StatusBadge.yellow('Pending'),
            ),
            SizedBox(
              width: 100,
              child: s.status == 'paid'
                  ? const SizedBox.shrink()
                  : ElevatedButton(
                      onPressed: () => _confirmMarkPaid(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Mark Paid'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmMarkPaid(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Mark as paid?',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
        content: Text(
            'Mark ₹${s.totalFeeOwed.toStringAsFixed(0)} settlement for ${s.storeName} as paid?',
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
              await provider.markPaid(s.settlementId);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
