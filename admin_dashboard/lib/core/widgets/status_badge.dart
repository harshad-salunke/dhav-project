import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final _BadgeType type;

  const StatusBadge.green(this.label, {super.key}) : type = _BadgeType.green;
  const StatusBadge.red(this.label, {super.key}) : type = _BadgeType.red;
  const StatusBadge.yellow(this.label, {super.key}) : type = _BadgeType.yellow;
  const StatusBadge.blue(this.label, {super.key}) : type = _BadgeType.blue;
  const StatusBadge.grey(this.label, {super.key}) : type = _BadgeType.grey;

  factory StatusBadge.forOrderStatus(String status) {
    switch (status) {
      case 'delivered':
        return StatusBadge.green(status);
      case 'failed':
      case 'cancelled':
        return StatusBadge.red(status);
      case 'out_for_delivery':
      case 'dispatched':
        return StatusBadge.blue(status.replaceAll('_', ' '));
      case 'accepted':
      case 'packed':
        return StatusBadge.yellow(status);
      default:
        return StatusBadge.grey(status.replaceAll('_', ' '));
    }
  }

  factory StatusBadge.forStoreStatus(String status) {
    switch (status) {
      case 'Online':
        return StatusBadge.green(status);
      case 'Suspended':
        return StatusBadge.red(status);
      case 'Unverified':
        return StatusBadge.yellow(status);
      default:
        return StatusBadge.grey(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: colors.$1,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) _colors() {
    switch (type) {
      case _BadgeType.green:
        return (AppColors.green, AppColors.greenBg);
      case _BadgeType.red:
        return (AppColors.red, AppColors.redBg);
      case _BadgeType.yellow:
        return (AppColors.yellow, AppColors.yellowBg);
      case _BadgeType.blue:
        return (AppColors.blue, AppColors.blueBg);
      case _BadgeType.grey:
        return (AppColors.textSecondary, AppColors.border);
    }
  }
}

enum _BadgeType { green, red, yellow, blue, grey }
