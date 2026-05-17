import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/constants/app_routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Profile', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: c.iconBg,
                        child: Icon(Icons.store_rounded, color: c.textSecondary, size: 44),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Raj Kirana Store', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Kothrud, Pune — 411038', style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: c.greenBg, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: AppColors.green, size: 14),
                            const SizedBox(width: 4),
                            Text('Verified Partner', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 14),
                            const SizedBox(width: 4),
                            Text('0 Strikes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(title: 'STORE DETAILS', c: c, children: [
              _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: '+91 98765 43210', c: c),
              _InfoRow(icon: Icons.access_time_rounded, label: 'Hours', value: '8:00 AM – 10:00 PM', c: c),
              _InfoRow(icon: Icons.location_on_rounded, label: 'Area', value: 'Kothrud, Pune', c: c),
              _InfoRow(icon: Icons.category_rounded, label: 'Type', value: 'Kirana Store', c: c),
            ]),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'DELIVERY TEAM',
              c: c,
              trailing: GestureDetector(
                onTap: () {},
                child: Text('+ ADD', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1)),
              ),
              children: [
                _DeliveryBoyRow(name: 'Ramesh Kumar', status: 'Active', orders: 118, c: c),
                _DeliveryBoyRow(name: 'Suresh Patil', status: 'Active', orders: 94, c: c),
                _DeliveryBoyRow(name: 'Anil Sharma', status: 'On Delivery', orders: 76, c: c),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(title: 'SETTINGS', c: c, children: [
              _SettingRow(
                icon: Icons.dark_mode_rounded,
                label: 'Dark Mode',
                c: c,
                trailing: Switch(
                  value: themeProvider.isDark,
                  onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
                  activeThumbColor: AppColors.primary,
                ),
              ),
              _SettingRow(
                icon: Icons.notifications_rounded,
                label: 'Order Notifications',
                c: c,
                trailing: Switch(value: true, onChanged: (_) {}, activeThumbColor: AppColors.primary),
              ),
              _SettingRow(
                icon: Icons.language_rounded,
                label: 'Language',
                c: c,
                trailing: Text('English', style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.helpSupport),
                child: _SettingRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  c: c,
                  trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                child: _SettingRow(
                  icon: Icons.settings_rounded,
                  label: 'App Settings',
                  c: c,
                  trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
                ),
              ),
              _SettingRow(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                c: c,
                trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
              ),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.red, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.logout_rounded, color: AppColors.red, size: 20),
                      const SizedBox(width: 8),
                      Text('Sign Out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.red)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final DhavColors c;

  const _SectionCard({required this.title, required this.children, required this.c, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final DhavColors c;

  const _InfoRow({required this.icon, required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
        ],
      ),
    );
  }
}

class _DeliveryBoyRow extends StatelessWidget {
  final String name;
  final String status;
  final int orders;
  final DhavColors c;

  const _DeliveryBoyRow({required this.name, required this.status, required this.orders, required this.c});

  @override
  Widget build(BuildContext context) {
    final isActive = status != 'On Delivery';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: c.iconBg,
            child: Icon(Icons.person_rounded, color: c.textHint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                Text(status, style: GoogleFonts.inter(fontSize: 12, color: isActive ? AppColors.green : AppColors.primary)),
              ],
            ),
          ),
          Text('$orders orders', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
          const SizedBox(width: 10),
          Icon(Icons.more_vert_rounded, color: c.textHint, size: 20),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final DhavColors c;

  const _SettingRow({required this.icon, required this.label, required this.trailing, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: c.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: c.textPrimary)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}
