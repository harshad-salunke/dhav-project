import 'package:flutter/material.dart';

class DhavColors {
  final bool isDark;
  const DhavColors._(this.isDark);

  factory DhavColors.of(BuildContext context) =>
      DhavColors._(Theme.of(context).brightness == Brightness.dark);

  Color get scaffold => isDark ? const Color(0xFF1A1F2E) : const Color(0xFFF8F9FB);
  Color get card2 => isDark ? const Color(0xFF222840) : const Color(0xFFEEF1F8);
  Color get card => isDark ? const Color(0xFF2A3050) : Colors.white;
  Color get inputFill => isDark ? const Color(0xFF2A3050) : const Color(0xFFF1F5F9);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1E293B);
  Color get textSecondary => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get textHint => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get divider => isDark ? const Color(0xFF2E3654) : const Color(0xFFE2E8F0);
  Color get greenBg => isDark ? const Color(0xFF1E4620) : const Color(0xFFDCFCE7);
  Color get redBg => isDark ? const Color(0xFF4A1515) : const Color(0xFFFEE2E2);
  Color get bottomNav => isDark ? const Color(0xFF222840) : Colors.white;
  Color get iconBg => isDark ? const Color(0xFF2A3050) : const Color(0xFFF1F5F9);
  Color get diagonalLines =>
      isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03);
}

extension DhavColorsExt on BuildContext {
  DhavColors get colors => DhavColors.of(this);
}
