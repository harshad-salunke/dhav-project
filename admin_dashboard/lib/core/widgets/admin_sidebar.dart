import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../constants/app_routes.dart';
import '../providers/auth_provider.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  static const _items = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: AppRoutes.dashboard),
    _NavItem(icon: Icons.storefront_rounded, label: 'Stores', route: AppRoutes.stores),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Orders', route: AppRoutes.orders),
    _NavItem(icon: Icons.people_rounded, label: 'Customers', route: AppRoutes.customers),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Settlements', route: AppRoutes.settlements),
    _NavItem(icon: Icons.inventory_2_rounded, label: 'Catalog', route: AppRoutes.catalog),
    _NavItem(icon: Icons.radar_rounded, label: 'Coverage', route: AppRoutes.coverage),
    _NavItem(icon: Icons.campaign_rounded, label: 'Notifications', route: AppRoutes.notifications),
  ];

  @override
  Widget build(BuildContext context) {
    final current = ModalRoute.of(context)?.settings.name ?? AppRoutes.dashboard;
    // Treat sub-routes as parent route for highlight purposes
    final activeRoute = (current == AppRoutes.storeDetail ||
            current == AppRoutes.storeOnboard)
        ? AppRoutes.stores
        : current == AppRoutes.customerDetail
            ? AppRoutes.customers
            : current;

    return Container(
      width: 220,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('DHAV',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Admin',
                      style: GoogleFonts.inter(
                          color: AppColors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _items.map((item) {
                final isSelected = activeRoute == item.route;
                return _NavTile(item: item, isSelected: isSelected);
              }).toList(),
            ),
          ),

          // Sign out
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: AppColors.textMuted, size: 20),
              title: Text('Sign out',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 13)),
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () async {
                await context.read<AuthProvider>().signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  const _NavTile({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? AppColors.orange.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (!isSelected) {
              Navigator.pushReplacementNamed(context, item.route);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 18,
                    color: isSelected ? AppColors.orange : AppColors.textSecondary),
                const SizedBox(width: 10),
                Text(item.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.orange
                          : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
