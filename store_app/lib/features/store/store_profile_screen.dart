import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/constants/app_routes.dart';

class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  bool _isEditable = false;
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Store Profile', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          if (_isEditable)
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() => _isEditable = false);
              },
              child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ),
          if (_isEditable)
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
                setState(() => _isEditable = false);
              },
              child: Text('Save', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          if (!_isEditable)
            IconButton(
              icon: Icon(Icons.edit_rounded, color: c.textPrimary, size: 24),
              onPressed: () => setState(() => _isEditable = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 48),
                      ),
                      if (_isEditable)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Raj Kirana Store', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text('Shop 4, Laxmi Complex, Kothrud, Pune', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatusBadge(label: 'Verified', color: AppColors.green),
                      const SizedBox(width: 8),
                      _StatusBadge(label: 'Gold Member', color: Colors.orange),
                      const SizedBox(width: 8),
                      _StatusBadge(label: 'Open', color: AppColors.green),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Store Info Grid
            Row(
              children: [
                _InfoCard(icon: Icons.star_rounded, label: 'Rating', value: '4.8', color: Colors.amber, c: c),
                _InfoCard(icon: Icons.local_shipping_rounded, label: 'Deliveries', value: '450+', color: AppColors.primary, c: c),
                _InfoCard(icon: Icons.check_circle_rounded, label: 'Success Rate', value: '98%', color: AppColors.green, c: c),
                _InfoCard(icon: Icons.work_rounded, label: 'Active Years', value: '5+', color: Colors.blue, c: c),
              ],
            ),
            const SizedBox(height: 20),

            // Team Members Section
            _SectionHeader(
              title: 'TEAM MEMBERS',
              actionText: 'Manage Team',
              onAction: () => Navigator.pushNamed(context, AppRoutes.storeTeam),
              c: c,
            ),
            const SizedBox(height: 12),
            _TeamMember(
              name: 'Ramesh Kumar',
              role: 'Store Manager',
              phone: '+91 98765 43210',
              status: 'Active',
              avatarColor: AppColors.primary,
              isAdmin: true,
              c: c,
            ),
            _TeamMember(
              name: 'Suresh Patil',
              role: 'Delivery Coordinator',
              phone: '+91 98765 43211',
              status: 'Active',
              avatarColor: Colors.orange,
              isAdmin: false,
              c: c,
            ),
            _TeamMember(
              name: 'Priya Sharma',
              role: 'Sales Executive',
              phone: '+91 98765 43212',
              status: 'Offline',
              avatarColor: AppColors.green,
              isAdmin: false,
              c: c,
            ),
            const SizedBox(height: 16),

            // Store Settings
            _SectionHeader(
              title: 'STORE SETTINGS',
              c: c,
            ),
            const SizedBox(height: 12),
            _SettingTile(
              icon: Icons.business_rounded,
              label: 'Store Information',
              subtitle: 'Name, address, category',
              trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
              onTap: () => _showEditStoreDialog(context),
            ),
            _SettingTile(
              icon: Icons.schedule_rounded,
              label: 'Working Hours',
              subtitle: 'Mon-Sat: 8AM-10PM',
              trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
              onTap: () => _showWorkingHoursDialog(context),
            ),
            _SettingTile(
              icon: Icons.notifications_rounded,
              label: 'Notifications',
              subtitle: 'Order alerts, earnings',
              trailing: Switch(
                value: true,
                onChanged: (v) => HapticFeedback.mediumImpact(),
                activeColor: AppColors.primary,
              ),
              onTap: () {},
            ),
            _SettingTile(
              icon: Icons.security_rounded,
              label: 'Security',
              subtitle: 'Change password, 2FA',
              trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
              onTap: () {},
            ),
            _SettingTile(
              icon: Icons.help_outline_rounded,
              label: 'Help & Support',
              subtitle: 'FAQs, contact us',
              trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
              onTap: () => Navigator.pushNamed(context, AppRoutes.helpSupport),
            ),
            _SettingTile(
              icon: Icons.logout_rounded,
              label: 'Logout',
              subtitle: 'Sign out from this account',
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.red),
              isDestructive: true,
              onTap: () => _showLogoutDialog(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showEditStoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _StoreEditDialog(title: 'Edit Store Information'),
    );
  }

  void _showWorkingHoursDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _WorkingHoursDialog(),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        content: Text('Are you sure you want to logout from your account?', style: GoogleFonts.inter(fontSize: 14, color: c.textHint)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textHint)),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
            },
            child: Text('Logout', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final DhavColors c;

  const _InfoCard({required this.icon, required this.label, required this.value, required this.color, required this.c});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: c.textHint)),
          ],
        ),
      ),
    );
  }
}

class _TeamMember extends StatelessWidget {
  final String name;
  final String role;
  final String phone;
  final String status;
  final Color avatarColor;
  final bool isAdmin;
  final DhavColors c;

  const _TeamMember({
    required this.name,
    required this.role,
    required this.phone,
    required this.status,
    required this.avatarColor,
    required this.isAdmin,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.split(' ').map((e) => e[0]).take(2).join(),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: avatarColor),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 16),
                    ],
                  ],
                ),
                Text(role, style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                Text(phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'Active' ? AppColors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: status == 'Active' ? AppColors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: status == 'Active' ? AppColors.green : c.textHint)),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 6),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.settings_rounded, color: c.textHint, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final DhavColors c;

  const _SectionHeader({
    required this.title,
    this.actionText,
    this.onAction,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionText!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5)),
          ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget trailing;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.trailing,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = isDestructive ? AppColors.red : c.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive ? AppColors.red.withValues(alpha: 0.12) : c.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isDestructive ? AppColors.red : c.textPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                ],
              ),
            ),
            if (trailing is Switch) const SizedBox(width: 10) else trailing,
          ],
        ),
      ),
    );
  }
}

class _StoreEditDialog extends StatefulWidget {
  final String title;

  const _StoreEditDialog({required this.title});

  @override
  State<_StoreEditDialog> createState() => _StoreEditDialogState();
}

class _StoreEditDialogState extends State<_StoreEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Raj Kirana Store');
  final _addressController = TextEditingController(text: 'Shop 4, Laxmi Complex, Kothrud, Pune 411038');
  final _phoneController = TextEditingController(text: '+91 98765 43210');
  final _emailController = TextEditingController(text: 'rajstore@example.com');

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: c.textHint),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(controller: _nameController, label: 'Store Name', icon: Icons.business_rounded),
                  const SizedBox(height: 14),
                  _buildTextField(controller: _addressController, label: 'Address', icon: Icons.location_on_rounded),
                  const SizedBox(height: 14),
                  _buildTextField(controller: _phoneController, label: 'Phone Number', icon: Icons.phone_rounded),
                  const SizedBox(height: 14),
                  _buildTextField(controller: _emailController, label: 'Email', icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: c.iconBg,
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store information updated')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text('Save Changes', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) => value == null || value.isEmpty ? 'Please enter $label' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: context.colors.iconBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _WorkingHoursDialog extends StatefulWidget {
  @override
  State<_WorkingHoursDialog> createState() => _WorkingHoursDialogState();
}

class _WorkingHoursDialogState extends State<_WorkingHoursDialog> {
  final Map<int, Map<String, bool>> _hours = {
    0: {'open': false, 'close': false}, // Sunday
    1: {'open': true, 'close': true},
    2: {'open': true, 'close': true},
    3: {'open': true, 'close': true},
    4: {'open': true, 'close': true},
    5: {'open': true, 'close': true},
    6: {'open': true, 'close': true}, // Saturday
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Working Hours', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: c.textHint),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < 7; i++) ...[
              _DayRow(
                day: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][i],
                dayIndex: i,
                isOpen: _hours[i]!['open']!,
                isClosed: _hours[i]!['close']!,
                onToggle: (open, close) {
                  setState(() {
                    _hours[i] = {'open': open, 'close': close};
                  });
                },
              ),
              if (i < 6) const Divider(height: 24, color: AppColors.border),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Working hours updated')));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: Text('Save Hours', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String day;
  final int dayIndex;
  final bool isOpen;
  final bool isClosed;
  final Function(bool, bool) onToggle;

  const _DayRow({
    required this.day,
    required this.dayIndex,
    required this.isOpen,
    required this.isClosed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        SizedBox(width: 40, child: Text(day, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary))),
        Expanded(
          child: Row(
            children: [
              Checkbox(
                value: isOpen,
                onChanged: (v) => onToggle(v!, isClosed),
                activeColor: AppColors.primary,
              ),
              Text('Open', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
              const SizedBox(width: 20),
              Checkbox(
                value: isClosed,
                onChanged: (v) => onToggle(isOpen, v!),
                activeColor: AppColors.red,
              ),
              Text('Close', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
