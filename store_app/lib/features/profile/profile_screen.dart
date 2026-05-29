import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/models/store.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<StoreProvider>();
      if (store.store == null) store.loadMyStore();
      store.loadDeliveryBoys();
    });
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthProvider>();
    final storeProv = context.read<StoreProvider>();
    final navigator = Navigator.of(context);
    await auth.signOut();
    storeProv.reset();
    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final themeProvider = context.watch<ThemeProvider>();
    final store = context.watch<StoreProvider>().store;
    final boys = context.watch<StoreProvider>().deliveryBoys;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Profile',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _profileCard(c, store),
            const SizedBox(height: 16),
            _SectionCard(title: 'STORE DETAILS', c: c, children: [
              _InfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: store?.phone ?? '—',
                  c: c),
              _InfoRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: store?.email ?? '—',
                  c: c),
              _InfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Hours',
                  value: store?.operatingHours == null
                      ? '—'
                      : '${store!.operatingHours!.open} – ${store.operatingHours!.close}',
                  c: c),
              _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Address',
                  value: store?.address ?? '—',
                  c: c),
            ]),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'DELIVERY TEAM',
              c: c,
              trailing: GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.storeTeam),
                child: Text('MANAGE',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1)),
              ),
              children: [
                if (boys.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No delivery partners yet.',
                        style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                  )
                else
                  ...boys.take(3).map((b) => _DeliveryBoyRow(boy: b, c: c)),
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
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _signOut,
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
                      Text('Sign Out',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red)),
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

  Widget _profileCard(DhavColors c, Store? store) {
    return Container(
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
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.storeProfile),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.card, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(store?.shopName ?? 'Store',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(store?.address ?? '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (store?.isVerified == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: c.greenBg, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: AppColors.green, size: 14),
                      const SizedBox(width: 4),
                      Text('Verified Partner',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green)),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: c.iconBg, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: (store?.strikeCount ?? 0) > 0
                            ? AppColors.red
                            : AppColors.primary,
                        size: 14),
                    const SizedBox(width: 4),
                    Text('${store?.strikeCount ?? 0} Strikes',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final DhavColors c;

  const _SectionCard(
      {required this.title, required this.children, required this.c, this.trailing});

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
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textHint,
                      letterSpacing: 1.5)),
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

  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
          const Spacer(),
          Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _DeliveryBoyRow extends StatelessWidget {
  final DeliveryBoy boy;
  final DhavColors c;

  const _DeliveryBoyRow({required this.boy, required this.c});

  @override
  Widget build(BuildContext context) {
    final onDelivery = boy.currentOrderId != null;
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
                Text(boy.name,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                Text(onDelivery ? 'On Delivery' : 'Available',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: onDelivery ? AppColors.primary : AppColors.green)),
              ],
            ),
          ),
          Text(boy.phone, style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
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

  const _SettingRow(
      {required this.icon,
      required this.label,
      required this.trailing,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: c.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.inter(fontSize: 14, color: c.textPrimary)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}
