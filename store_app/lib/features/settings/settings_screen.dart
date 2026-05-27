import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _orderAlerts = true;
  bool _earningsAlerts = true;
  bool _systemAlerts = false;
  String _language = 'English';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance
            _SectionLabel(label: 'APPEARANCE', c: c),
            _SettingsCard(c: c, children: [
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
            ]),
            const SizedBox(height: 20),

            // Notifications
            _SectionLabel(label: 'NOTIFICATIONS', c: c),
            _SettingsCard(c: c, children: [
              _SettingRow(
                icon: Icons.shopping_bag_rounded,
                label: 'Order Alerts',
                sub: 'New orders, cancellations',
                c: c,
                trailing: Switch(
                  value: _orderAlerts,
                  onChanged: (v) => setState(() => _orderAlerts = v),
                  activeThumbColor: AppColors.primary,
                ),
              ),
              _Divider(c: c),
              _SettingRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Earnings & Payments',
                sub: 'Settlement, fee reminders',
                c: c,
                trailing: Switch(
                  value: _earningsAlerts,
                  onChanged: (v) => setState(() => _earningsAlerts = v),
                  activeThumbColor: AppColors.primary,
                ),
              ),
              _Divider(c: c),
              _SettingRow(
                icon: Icons.info_outline_rounded,
                label: 'System Alerts',
                sub: 'App updates, maintenance',
                c: c,
                trailing: Switch(
                  value: _systemAlerts,
                  onChanged: (v) => setState(() => _systemAlerts = v),
                  activeThumbColor: AppColors.primary,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Language
            _SectionLabel(label: 'LANGUAGE & REGION', c: c),
            _SettingsCard(c: c, children: [
              _SettingRow(
                icon: Icons.language_rounded,
                label: 'App Language',
                c: c,
                trailing: DropdownButton<String>(
                  value: _language,
                  underline: const SizedBox(),
                  style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
                  dropdownColor: c.card,
                  items: ['English', 'Marathi', 'Hindi'].map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text(lang, style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _language = v!),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // About
            _SectionLabel(label: 'ABOUT', c: c),
            _SettingsCard(c: c, children: [
              _SettingRow(
                icon: Icons.info_rounded,
                label: 'App Version',
                c: c,
                trailing: Text('v2.0.0', style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
              ),
              _Divider(c: c),
              _SettingRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                c: c,
                trailing: Icon(Icons.open_in_new_rounded, color: c.textHint, size: 18),
                onTap: () async {
                  final uri = Uri.parse('https://dhav.in/privacy');
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _Divider(c: c),
              _SettingRow(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                c: c,
                trailing: Icon(Icons.open_in_new_rounded, color: c.textHint, size: 18),
                onTap: () async {
                  final uri = Uri.parse('https://dhav.in/terms');
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final DhavColors c;
  const _SectionLabel({required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final DhavColors c;
  final List<Widget> children;
  const _SettingsCard({required this.c, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final DhavColors c;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.c,
    required this.trailing,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: c.textPrimary)),
                  if (sub != null)
                    Text(sub!, style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final DhavColors c;
  const _Divider({required this.c});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: c.divider, indent: 52, endIndent: 0);
  }
}
