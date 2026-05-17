import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/constants/app_routes.dart';

class StoreTeamScreen extends StatefulWidget {
  const StoreTeamScreen({super.key});

  @override
  State<StoreTeamScreen> createState() => _StoreTeamScreenState();
}

class _StoreTeamScreenState extends State<StoreTeamScreen> {
  final List<Map<String, dynamic>> _teamMembers = [
    {'id': 1, 'name': 'Ramesh Kumar', 'role': 'Store Manager', 'phone': '+91 98765 43210', 'email': 'ramesh@dhav.com', 'status': 'Active', 'joined': 'Jan 2021', 'isAdmin': true, 'orders': 450},
    {'id': 2, 'name': 'Suresh Patil', 'role': 'Delivery Coordinator', 'phone': '+91 98765 43211', 'email': 'suresh@dhav.com', 'status': 'Active', 'joined': 'Mar 2021', 'isAdmin': false, 'orders': 380},
    {'id': 3, 'name': 'Priya Sharma', 'role': 'Sales Executive', 'phone': '+91 98765 43212', 'email': 'priya@dhav.com', 'status': 'Offline', 'joined': 'Jun 2021', 'isAdmin': false, 'orders': 210},
    {'id': 4, 'name': 'Amit Yadav', 'role': 'Store Helper', 'phone': '+91 98765 43213', 'email': 'amit@dhav.com', 'status': 'Offline', 'joined': 'Sep 2021', 'isAdmin': false, 'orders': 150},
  ];

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
        title: Text('Team Members', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: c.textPrimary, size: 26),
            onPressed: () => _showAddMemberDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Team Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _TeamStat(label: 'Total', value: '${_teamMembers.length}', c: c),
                const SizedBox(width: 10),
                _TeamStat(label: 'Active', value: '2', color: AppColors.green, c: c),
                const SizedBox(width: 10),
                _TeamStat(label: 'Offline', value: '2', color: Colors.grey, c: c),
                const SizedBox(width: 10),
                _TeamStat(label: 'Orders', value: '1,190', c: c),
              ],
            ),
          ),

          // Team List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _teamMembers.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _TeamMemberCard(member: _teamMembers[i], c: c),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _phoneController = TextEditingController();
    final _roleController = TextEditingController(text: 'Delivery Boy');

    final _roles = ['Store Manager', 'Delivery Coordinator', 'Sales Executive', 'Delivery Boy', 'Store Helper'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Add Team Member', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: context.colors.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_rounded,
                    hint: 'Enter name',
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_rounded,
                    hint: 'Enter email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    hint: 'Enter phone',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: 'Delivery Boy',
                    decoration: InputDecoration(
                      labelText: 'Role',
                      prefixIcon: const Icon(Icons.work_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: context.colors.iconBg,
                    ),
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              setState(() {
                                _teamMembers.add({
                                  'id': _teamMembers.length + 1,
                                  'name': _nameController.text,
                                  'role': 'Delivery Boy',
                                  'phone': _phoneController.text,
                                  'email': _emailController.text,
                                  'status': 'Offline',
                                  'joined': 'Today',
                                  'isAdmin': false,
                                  'orders': 0,
                                });
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team member added successfully')));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: Text('Add Member', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        hintText: hint,
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

class _TeamStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final DhavColors c;

  const _TeamStat({required this.label, required this.value, this.color, required this.c});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color != null ? color!.withValues(alpha: 0.08) : c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color != null ? color!.withValues(alpha: 0.2) : c.divider, width: 1),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: c.textHint)),
          ],
        ),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final DhavColors c;

  const _TeamMemberCard({required this.member, required this.c});

  @override
  Widget build(BuildContext context) {
    final statusColor = member['status'] == 'Active' ? AppColors.green : Colors.grey;
    final statusBg = member['status'] == 'Active' ? AppColors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                member['name'].split(' ').map((e) => e[0]).take(2).join(),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member['name'] as String, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    if (member['isAdmin'] as bool) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: member['isAdmin'] as bool ? AppColors.primary.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        member['role'] as String,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: member['isAdmin'] as bool ? AppColors.primary : Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member['status'] as String,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member['phone'] as String,
                  style: GoogleFonts.inter(fontSize: 11, color: c.textHint),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: c.textHint, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${member['orders']}',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                ],
              ),
              Text('orders', style: GoogleFonts.inter(fontSize: 9, color: c.textHint)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: c.textHint, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    member['joined'] as String,
                    style: GoogleFonts.inter(fontSize: 9, color: c.textHint),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => _showMemberMenu(context, member),
            icon: Icon(Icons.more_vert_rounded, color: c.textHint, size: 20),
          ),
        ],
      ),
    );
  }

  void _showMemberMenu(BuildContext context, Map<String, dynamic> member) {
    final c = context.colors;
    final menuItems = [
      {'icon': Icons.person_rounded, 'label': 'View Profile', 'color': c.textPrimary},
      {'icon': Icons.settings_rounded, 'label': 'Edit Details', 'color': c.textPrimary},
      if (!member['isAdmin'] as bool)
        {'icon': Icons.admin_panel_settings_rounded, 'label': 'Make Admin', 'color': AppColors.primary},
      if (member['isAdmin'] as bool)
        {'icon': Icons.person_remove_rounded, 'label': 'Remove Admin', 'color': AppColors.red},
      {'icon': Icons.history_rounded, 'label': 'Delivery History', 'color': c.textPrimary},
      {'icon': Icons.delete_rounded, 'label': 'Remove Member', 'color': AppColors.red},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberMenu(
        items: menuItems,
        onSelected: (index) {
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
          final action = menuItems[index]['label'];
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action clicked for ${member['name']}')));
        },
      ),
    );
  }
}

class _MemberMenu extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Function(int) onSelected;

  const _MemberMenu({required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) => _MenuItem(
                  item: items[i],
                  index: i,
                  onSelected: onSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final Function(int) onSelected;

  const _MenuItem({required this.item, required this.index, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        item['icon'],
        color: item['color'],
        size: 22,
      ),
      title: Text(
        item['label'],
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.border),
      onTap: () => onSelected(index),
    );
  }
}
