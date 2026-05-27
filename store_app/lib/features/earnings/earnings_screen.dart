import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/settlement.dart';
import '../../core/providers/earnings_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EarningsProvider>().load();
      final sp = context.read<StoreProvider>();
      if (sp.store == null) sp.loadMyStore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<EarningsProvider>();
    final store = context.watch<StoreProvider>().store;
    // Derive UPI ID: prefer phone@paytm (common in India), fallback to phone only
    final storePhone = store?.phone ?? '';
    final upiId = storePhone.isNotEmpty
        ? '${storePhone.replaceAll(RegExp(r'[^0-9]'), '')}@paytm'
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: SafeArea(
        child: Column(
          children: [
            const _TopHeader(),
            Expanded(
              child: prov.loading
                  ? const EarningsShimmer()
                  : prov.error != null
                      ? Center(
                          child: Text(prov.error!,
                              style: GoogleFonts.inter(color: AppColors.red)))
                      : RefreshIndicator(
                          onRefresh: () => prov.load(),
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _CurrentWeekCard(
                                  settlement: prov.current, upiId: upiId),
                              const SizedBox(height: 22),
                              _SectionLabel(text: 'PAST WEEKLY HISTORY'),
                              const SizedBox(height: 12),
                              if (prov.history.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                      'No past settlements yet.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Colors.white54)),
                                )
                              else
                                ...prov.history.map((s) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _PastWeekTile(settlement: s),
                                    )),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text('Earnings',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class _CurrentWeekCard extends StatelessWidget {
  final WeeklySettlement? settlement;
  final String? upiId;
  const _CurrentWeekCard({required this.settlement, this.upiId});

  @override
  Widget build(BuildContext context) {
    if (settlement == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            const Icon(Icons.savings_outlined, color: Colors.white54, size: 32),
            const SizedBox(height: 8),
            Text('No active settlement this week.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }
    final s = settlement!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CURRENT WEEK ${s.weekStart} → ${s.weekEnd}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      letterSpacing: 1.3)),
              const SizedBox(height: 10),
              Text('₹${s.balanceDue.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text('Balance owed to DHAV',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MiniMetric(label: 'DELIVERED', value: '${s.totalOrdersDelivered}'),
                  const SizedBox(width: 14),
                  _MiniMetric(
                      label: 'OWED',
                      value: '₹${s.totalPlatformFeeOwed.toStringAsFixed(0)}'),
                  const SizedBox(width: 14),
                  _MiniMetric(
                      label: 'PAID',
                      value: '₹${s.totalFeePaid.toStringAsFixed(0)}'),
                ],
              ),
              if (s.isOverdue) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('OVERDUE — store is delisted until paid',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _UpiPayCard(upiId: upiId),
      ],
    );
  }
}

// ── UPI pay card ─────────────────────────────────────────────────────────────

class _UpiPayCard extends StatelessWidget {
  final String? upiId;
  const _UpiPayCard({this.upiId});

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('UPI ID copied: $text',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayUpi = upiId ?? 'dhav@upi';
    final isPlaceholder = upiId == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay DHAV via UPI',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      displayUpi,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isPlaceholder
                            ? Colors.white38
                            : Colors.white70,
                        fontStyle: isPlaceholder
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    if (isPlaceholder) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(contact support to configure)',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isPlaceholder)
            IconButton(
              onPressed: () => _copyToClipboard(context, displayUpi),
              icon: const Icon(Icons.copy_rounded,
                  color: AppColors.primary, size: 18),
              tooltip: 'Copy UPI ID',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

// ── Mini metric ───────────────────────────────────────────────────────────────

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: Colors.white60, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white54,
            letterSpacing: 1.5));
  }
}

class _PastWeekTile extends StatelessWidget {
  final WeeklySettlement settlement;
  const _PastWeekTile({required this.settlement});

  Color get _statusColor {
    switch (settlement.status) {
      case 'settled':
        return AppColors.green;
      case 'partially_paid':
        return Colors.orange;
      default:
        return AppColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paidDate = settlement.paymentRecords.isEmpty
        ? null
        : DateFormat('d MMM').format(DateTime.fromMillisecondsSinceEpoch(
            settlement.paymentRecords.last.paymentDate));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${settlement.weekStart} → ${settlement.weekEnd}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                    '${settlement.totalOrdersDelivered} orders • Fee ₹${settlement.totalPlatformFeeOwed.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white60)),
                if (paidDate != null)
                  Text('Paid $paidDate',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white60)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text(settlement.status.toUpperCase().replaceAll('_', ' '),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _statusColor)),
          ),
        ],
      ),
    );
  }
}
