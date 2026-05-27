import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/notifications_provider.dart';
import '../../core/providers/stores_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_sidebar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Form state
  String _target = 'all_customers';
  String _type = 'announcement';
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _storeIdCtrl = TextEditingController();
  final _customerUidCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Target options
  static const _targets = [
    _Option('all_customers', '👤 All Customers', 'Notify every customer on DHAV'),
    _Option('all_stores', '🏪 All Stores', 'Notify every store owner on DHAV'),
    _Option('specific_store', '🏬 Specific Store', 'Target a single store owner'),
    _Option('specific_customer', '👥 Specific Customer', 'Target a single customer'),
  ];

  // Notification type options
  static const _types = [
    _Option('announcement', '📣 Announcement', 'General platform update'),
    _Option('offer', '🎁 Offer / Promo', 'Deals, discounts, or promos'),
    _Option('system', '⚙️ System', 'Maintenance, downtime alerts'),
    _Option('order_update', '📦 Order Update', 'Order-related information'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _storeIdCtrl.dispose();
    _customerUidCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<AdminNotificationsProvider>();
    prov.reset();
    final ok = await prov.broadcast(
      target: _target,
      title: _titleCtrl.text.trim(),
      message: _msgCtrl.text.trim(),
      type: _type,
      storeId: _target == 'specific_store' ? _storeIdCtrl.text.trim() : null,
      customerUid:
          _target == 'specific_customer' ? _customerUidCtrl.text.trim() : null,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Sent! ${prov.lastResult?['recipients'] ?? ''} recipient(s) • ${prov.lastResult?['push_sent'] ?? 0} push, ${prov.lastResult?['persisted'] ?? 0} persisted',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ));
      _titleCtrl.clear();
      _msgCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(prov.error ?? 'Unknown error',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminNotificationsProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                        bottom: BorderSide(color: AppColors.border, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded,
                          color: AppColors.orange, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Notifications',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      Text(
                        'Broadcast push notifications to users',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Target ──────────────────────────────────────
                            _SectionHeader(title: 'Target Audience'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _targets.map((opt) {
                                final selected = _target == opt.value;
                                return _TargetChip(
                                  opt: opt,
                                  selected: selected,
                                  onTap: () => setState(() => _target = opt.value),
                                );
                              }).toList(),
                            ),

                            // Extra field for specific targets
                            if (_target == 'specific_store') ...[
                              const SizedBox(height: 16),
                              _InputField(
                                controller: _storeIdCtrl,
                                label: 'Store ID',
                                hint: 'Paste the store_id from the Stores table',
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Store ID required'
                                    : null,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.search_rounded,
                                      color: AppColors.textMuted, size: 18),
                                  onPressed: () => _pickStore(context),
                                  tooltip: 'Pick from stores list',
                                ),
                              ),
                            ],
                            if (_target == 'specific_customer') ...[
                              const SizedBox(height: 16),
                              _InputField(
                                controller: _customerUidCtrl,
                                label: 'Customer UID',
                                hint: 'Firebase UID of the customer',
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Customer UID required'
                                    : null,
                              ),
                            ],

                            const SizedBox(height: 28),

                            // ── Notification type ────────────────────────────
                            _SectionHeader(title: 'Notification Type'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _types.map((opt) {
                                final selected = _type == opt.value;
                                return _TargetChip(
                                  opt: opt,
                                  selected: selected,
                                  onTap: () => setState(() => _type = opt.value),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 28),

                            // ── Message ──────────────────────────────────────
                            _SectionHeader(title: 'Message'),
                            const SizedBox(height: 12),
                            _InputField(
                              controller: _titleCtrl,
                              label: 'Title',
                              hint: 'Short, punchy headline (50 chars max)',
                              maxLength: 80,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Title is required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _InputField(
                              controller: _msgCtrl,
                              label: 'Message body',
                              hint: 'Details of the notification...',
                              maxLines: 4,
                              maxLength: 300,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Message body is required'
                                  : null,
                            ),

                            const SizedBox(height: 32),

                            // ── Preview ──────────────────────────────────────
                            _NotificationPreview(
                              title: _titleCtrl.text,
                              body: _msgCtrl.text,
                              type: _type,
                            ),

                            const SizedBox(height: 28),

                            // ── Send button ──────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: prov.isSending ? null : _send,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  disabledBackgroundColor:
                                      AppColors.orange.withValues(alpha: 0.4),
                                ),
                                icon: prov.isSending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send_rounded, size: 18),
                                label: Text(
                                  prov.isSending
                                      ? 'Sending…'
                                      : 'Send Notification',
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // ── Recent history ───────────────────────────────
                            _RecentHistorySection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Quick-pick a store ID from the stores dropdown
  Future<void> _pickStore(BuildContext context) async {
    final stores = context.read<StoresProvider>();
    if (stores.stores.isEmpty) await stores.loadStores();
    if (!mounted) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => _StorePickerDialog(stores: stores),
    );
    if (picked != null) {
      _storeIdCtrl.text = picked;
      setState(() {});
    }
  }
}

// ── Store picker dialog ────────────────────────────────────────────────────────

class _StorePickerDialog extends StatelessWidget {
  final StoresProvider stores;
  const _StorePickerDialog({required this.stores});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Pick a store',
          style: GoogleFonts.inter(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: stores.stores.length,
          itemBuilder: (_, i) {
            final s = stores.stores[i];
            return ListTile(
              title: Text(s.name,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 14)),
              subtitle: Text(s.storeId,
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
              onTap: () => Navigator.pop(context, s.storeId),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

// ── Notification preview ───────────────────────────────────────────────────────

class _NotificationPreview extends StatelessWidget {
  final String title;
  final String body;
  final String type;
  const _NotificationPreview(
      {required this.title, required this.body, required this.type});

  IconData get _icon {
    switch (type) {
      case 'offer':
        return Icons.local_offer_rounded;
      case 'system':
        return Icons.settings_rounded;
      case 'order_update':
        return Icons.receipt_long_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color get _color {
    switch (type) {
      case 'offer':
        return AppColors.orange;
      case 'system':
        return AppColors.yellow;
      case 'order_update':
        return AppColors.blue;
      default:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = title.isNotEmpty || body.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smartphone_rounded,
                  color: AppColors.textMuted, size: 14),
              const SizedBox(width: 6),
              Text('Preview',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasContent)
            Text('Fill in the title and message to see a preview.',
                style:
                    GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: _color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Title' : title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body.isEmpty ? 'Message body…' : body,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('Just now',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textMuted)),
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

// ── Recent history section ─────────────────────────────────────────────────────

class _RecentHistorySection extends StatefulWidget {
  const _RecentHistorySection();

  @override
  State<_RecentHistorySection> createState() => _RecentHistorySectionState();
}

class _RecentHistorySectionState extends State<_RecentHistorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminNotificationsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            setState(() => _expanded = !_expanded);
            if (_expanded && prov.recentHistory.isEmpty) {
              await prov.loadHistory();
            }
          },
          child: Row(
            children: [
              Text('Recent Notification History',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const Spacer(),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          if (prov.historyLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    color: AppColors.orange, strokeWidth: 2),
              ),
            )
          else if (prov.recentHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No notifications sent yet.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textMuted)),
            )
          else
            ...prov.recentHistory.map((n) => _HistoryTile(notif: n)).toList(),
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _HistoryTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final createdAt = notif['created_at'] as int?;
    final timeStr = createdAt != null
        ? _formatDate(DateTime.fromMillisecondsSinceEpoch(createdAt))
        : '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif['title'] as String? ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(notif['body'] as String? ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TypeBadge(type: notif['type'] as String? ?? 'system'),
              const SizedBox(height: 4),
              Text(timeStr,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  Color get _color {
    switch (type) {
      case 'offer':
        return AppColors.orange;
      case 'system':
        return AppColors.yellow;
      case 'order_update':
        return AppColors.blue;
      default:
        return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6)),
      child: Text(
        type.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _color,
            letterSpacing: 0.5),
      ),
    );
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5));
  }
}

class _Option {
  final String value;
  final String label;
  final String description;
  const _Option(this.value, this.label, this.description);
}

class _TargetChip extends StatelessWidget {
  final _Option opt;
  final bool selected;
  final VoidCallback onTap;
  const _TargetChip(
      {required this.opt, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.orange.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.orange.withValues(alpha: 0.6)
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(opt.label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.orange
                        : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(opt.description,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int? maxLength;
  final int maxLines;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.card,
            counterStyle:
                GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.red),
            ),
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
