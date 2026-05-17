import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class MissedOrderScreen extends StatelessWidget {
  const MissedOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: c.redBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.warning_rounded, color: AppColors.red, size: 52),
              ),
              const SizedBox(height: 28),
              Text(
                'Order Missed!',
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: c.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'You missed Order #OD-9928. Repeated misses may affect your store rating and priority score.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 15, color: c.textHint, height: 1.6),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _WarningRow(icon: Icons.timer_off_rounded, text: 'Auto-rejected after 45 seconds', c: c),
                    const SizedBox(height: 12),
                    _WarningRow(icon: Icons.trending_down_rounded, text: 'Priority score reduced by 5 points', c: c),
                    const SizedBox(height: 12),
                    _WarningRow(icon: Icons.warning_amber_rounded, text: '3 misses may trigger a warning', c: c),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Strike 1 of 3. After 3 strikes you will be temporarily suspended.',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.red, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Text('Go to Dashboard', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final DhavColors c;

  const _WarningRow({required this.icon, required this.text, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: c.textHint, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary))),
      ],
    );
  }
}
