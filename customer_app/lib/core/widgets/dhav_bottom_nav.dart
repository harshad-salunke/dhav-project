import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/app_routes.dart';

class DhavBottomNav extends StatelessWidget {
  final int currentIndex;

  const DhavBottomNav({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    final routes = [
      AppRoutes.home,
      AppRoutes.search,
      AppRoutes.orderHistory,
      AppRoutes.profile,
    ];
    if (index == currentIndex) return;
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, currentIndex: currentIndex, onTap: (i) => _onTap(context, i)),
              _NavItem(icon: Icons.search_rounded, label: 'Search', index: 1, currentIndex: currentIndex, onTap: (i) => _onTap(context, i)),
              _NavItem(icon: Icons.shopping_bag_outlined, label: 'Orders', index: 2, currentIndex: currentIndex, onTap: (i) => _onTap(context, i)),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', index: 3, currentIndex: currentIndex, onTap: (i) => _onTap(context, i)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? AppColors.navActive : AppColors.navInactive,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: active ? AppColors.navActive : AppColors.navInactive,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
