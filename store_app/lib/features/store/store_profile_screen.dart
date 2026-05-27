import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_routes.dart';
import '../../core/models/store.dart';
import '../../core/providers/store_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<StoreProvider>();
      if (sp.store == null) sp.loadMyStore();
      sp.loadDeliveryBoys();
    });
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _openEditSheet(Store store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditStoreSheet(store: store),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sp = context.watch<StoreProvider>();
    final store = sp.store;
    final boys = sp.deliveryBoys;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Store Profile',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary)),
        actions: [
          if (store != null)
            IconButton(
              icon: Icon(Icons.edit_rounded, color: c.textPrimary, size: 24),
              tooltip: 'Edit store info',
              onPressed: () {
                HapticFeedback.mediumImpact();
                _openEditSheet(store);
              },
            ),
        ],
      ),
      body: sp.loading && store == null
          ? _buildShimmer(c)
          : store == null
              ? _buildError(c, sp.error)
              : RefreshIndicator(
                  onRefresh: () async {
                    await sp.loadMyStore();
                    await sp.loadDeliveryBoys();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(c, store),
                        const SizedBox(height: 20),
                        _buildStatsRow(c, store),
                        const SizedBox(height: 20),
                        _buildContactCard(c, store),
                        const SizedBox(height: 20),
                        _buildHoursCard(c, store),
                        const SizedBox(height: 20),
                        _buildTeamSection(c, boys),
                        const SizedBox(height: 20),
                        _buildSettingsList(c),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ── Hero Card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(DhavColors c, Store store) {
    final successRate = store.totalOrdersAccepted + store.totalOrdersFailed > 0
        ? (store.totalOrdersAccepted /
                (store.totalOrdersAccepted + store.totalOrdersFailed) *
                100)
            .toStringAsFixed(0)
        : '—';

    return Container(
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: store.shopPhotoUrl != null
                ? ClipOval(
                    child: Image.network(store.shopPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 48)),
                  )
                : const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 48),
          ),
          const SizedBox(height: 12),
          Text(store.shopName,
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(store.address,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white70),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (store.isVerified)
                _StatusBadge(label: 'Verified', color: AppColors.green),
              _StatusBadge(
                label: store.isOpen ? 'Open' : 'Closed',
                color: store.isOpen ? AppColors.green : AppColors.red,
              ),
              if (store.isSuspended)
                const _StatusBadge(label: 'Suspended', color: AppColors.red),
              _StatusBadge(label: '$successRate% Success', color: Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(DhavColors c, Store store) {
    return Row(
      children: [
        _InfoCard(
            icon: Icons.star_rounded,
            label: 'Rating',
            value: store.rating > 0
                ? store.rating.toStringAsFixed(1)
                : '—',
            color: Colors.amber,
            c: c),
        const SizedBox(width: 8),
        _InfoCard(
            icon: Icons.check_circle_rounded,
            label: 'Delivered',
            value: '${store.totalOrdersAccepted}',
            color: AppColors.green,
            c: c),
        const SizedBox(width: 8),
        _InfoCard(
            icon: Icons.warning_amber_rounded,
            label: 'Strikes',
            value: '${store.strikeCount}',
            color: store.strikeCount > 0 ? AppColors.red : AppColors.primary,
            c: c),
        const SizedBox(width: 8),
        _InfoCard(
            icon: Icons.inventory_2_rounded,
            label: 'Items',
            value: '${store.availableItemIds.length}',
            color: Colors.blue,
            c: c),
      ],
    );
  }

  // ── Contact Card ──────────────────────────────────────────────────────────

  Widget _buildContactCard(DhavColors c, Store store) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONTACT INFO',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textHint,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          _ContactRow(
            icon: Icons.phone_rounded,
            label: store.phone.isNotEmpty ? store.phone : '—',
            onTap: store.phone.isNotEmpty
                ? () => _callPhone(store.phone)
                : null,
            c: c,
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.email_rounded,
            label: store.email.isNotEmpty ? store.email : '—',
            c: c,
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.person_rounded,
            label: store.ownerName.isNotEmpty ? store.ownerName : '—',
            c: c,
          ),
        ],
      ),
    );
  }

  // ── Hours Card ────────────────────────────────────────────────────────────

  Widget _buildHoursCard(DhavColors c, Store store) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.schedule_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Working Hours',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                Text(
                  store.operatingHours != null
                      ? '${store.operatingHours!.open} – ${store.operatingHours!.close}'
                      : 'Not configured',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: store.isOpen
                  ? AppColors.green.withValues(alpha: 0.12)
                  : AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: store.isOpen
                            ? AppColors.green
                            : AppColors.red,
                        shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  store.isOpen ? 'Open' : 'Closed',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: store.isOpen
                          ? AppColors.green
                          : AppColors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Delivery Team ─────────────────────────────────────────────────────────

  Widget _buildTeamSection(DhavColors c, List<DeliveryBoy> boys) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DELIVERY TEAM',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textHint,
                      letterSpacing: 1.5)),
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.storeTeam),
                child: Text('MANAGE',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (boys.isEmpty)
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.storeTeam),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2))),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Text('Add your first delivery partner',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            )
          else
            ...boys.take(3).map((b) => _DeliveryBoyRow(boy: b, c: c)),
          if (boys.length > 3) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.storeTeam),
              child: Text('+${boys.length - 3} more partners',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Settings List ─────────────────────────────────────────────────────────

  Widget _buildSettingsList(DhavColors c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SETTINGS',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textHint,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          _SettingTile(
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            subtitle: 'Order alerts, earnings',
            trailing:
                Icon(Icons.chevron_right_rounded, color: c.textHint),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
          ),
          const SizedBox(height: 4),
          _SettingTile(
            icon: Icons.settings_rounded,
            label: 'App Settings',
            subtitle: 'Theme, language, preferences',
            trailing:
                Icon(Icons.chevron_right_rounded, color: c.textHint),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.settings),
          ),
          const SizedBox(height: 4),
          _SettingTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            subtitle: 'FAQs, contact us',
            trailing:
                Icon(Icons.chevron_right_rounded, color: c.textHint),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.helpSupport),
          ),
        ],
      ),
    );
  }

  // ── Loading shimmer ───────────────────────────────────────────────────────

  Widget _buildShimmer(DhavColors c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          4,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 100,
            decoration: BoxDecoration(
                color: c.card, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildError(DhavColors c, String? error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: c.textHint),
          const SizedBox(height: 12),
          Text(error ?? 'Could not load store profile',
              style: GoogleFonts.inter(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await context.read<StoreProvider>().loadMyStore();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final DhavColors c;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.c,
  });

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
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
            Text(label,
                style:
                    GoogleFonts.inter(fontSize: 10, color: c.textHint),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final DhavColors c;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.c,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: onTap != null
                        ? AppColors.primary
                        : c.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          if (onTap != null)
            Icon(Icons.call_rounded, color: AppColors.primary, size: 18),
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
            radius: 20,
            backgroundColor: c.iconBg,
            child: Text(
              boy.name.isNotEmpty ? boy.name[0].toUpperCase() : 'D',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
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
                        color: onDelivery
                            ? AppColors.primary
                            : AppColors.green)),
              ],
            ),
          ),
          Text(boy.phone,
              style: GoogleFonts.inter(
                  fontSize: 12, color: c.textHint)),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c.textPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: c.textHint)),
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
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ─── Edit Store Bottom Sheet ──────────────────────────────────────────────────

class _EditStoreSheet extends StatefulWidget {
  final Store store;
  const _EditStoreSheet({required this.store});

  @override
  State<_EditStoreSheet> createState() => _EditStoreSheetState();
}

class _EditStoreSheetState extends State<_EditStoreSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;

  late TimeOfDay _openTime;
  late TimeOfDay _closeTime;

  bool _fetchingGps = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.store;
    _shopNameCtrl = TextEditingController(text: s.shopName);
    _ownerNameCtrl = TextEditingController(text: s.ownerName);
    _phoneCtrl = TextEditingController(text: s.phone);
    _addressCtrl = TextEditingController(text: s.address);
    _latCtrl = TextEditingController(text: s.location.lat.toStringAsFixed(6));
    _lngCtrl = TextEditingController(text: s.location.lng.toStringAsFixed(6));
    _openTime = _parseTime(s.operatingHours?.open ?? '09:00');
    _closeTime = _parseTime(s.operatingHours?.close ?? '22:00');
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool isOpen}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _openTime : _closeTime,
      helpText: isOpen ? 'Select opening time' : 'Select closing time',
    );
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  Future<void> _useGps() async {
    setState(() => _fetchingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _latCtrl.text = pos.latitude.toStringAsFixed(6);
      _lngCtrl.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final s = widget.store;
    final newShopName =
        _shopNameCtrl.text.trim() != s.shopName ? _shopNameCtrl.text.trim() : null;
    final newOwnerName =
        _ownerNameCtrl.text.trim() != s.ownerName ? _ownerNameCtrl.text.trim() : null;
    final newPhone =
        _phoneCtrl.text.trim() != s.phone ? _phoneCtrl.text.trim() : null;
    final newAddress =
        _addressCtrl.text.trim() != s.address ? _addressCtrl.text.trim() : null;

    final newLat = double.tryParse(_latCtrl.text.trim());
    final newLng = double.tryParse(_lngCtrl.text.trim());
    final latChanged = newLat != null && newLat != s.location.lat;
    final lngChanged = newLng != null && newLng != s.location.lng;

    final newOpenStr = _formatTime(_openTime);
    final newCloseStr = _formatTime(_closeTime);
    final hoursChanged = newOpenStr != (s.operatingHours?.open ?? '09:00') ||
        newCloseStr != (s.operatingHours?.close ?? '22:00');

    try {
      await context.read<StoreProvider>().updateProfile(
            shopName: newShopName,
            ownerName: newOwnerName,
            phone: newPhone,
            address: newAddress,
            lat: latChanged ? newLat : null,
            lng: lngChanged ? newLng : null,
            openTime: hoursChanged ? newOpenStr : null,
            closeTime: hoursChanged ? newCloseStr : null,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store profile updated'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: c.scaffold,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── drag handle ──────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.textHint.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Text('Edit Store Info',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: c.textSecondary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: c.textHint.withValues(alpha: 0.15), height: 1),
            // ── form ─────────────────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    _sectionLabel('BASIC INFO', c),
                    _field(
                      controller: _shopNameCtrl,
                      label: 'Shop Name',
                      icon: Icons.storefront_rounded,
                      c: c,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _ownerNameCtrl,
                      label: 'Owner Name',
                      icon: Icons.person_rounded,
                      c: c,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      icon: Icons.phone_rounded,
                      c: c,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.trim().length < 10) ? 'Enter valid phone' : null,
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('OPENING HOURS', c),
                    Row(
                      children: [
                        Expanded(
                          child: _timeTile(
                            label: 'Opens At',
                            time: _openTime,
                            icon: Icons.wb_sunny_rounded,
                            color: Colors.orange,
                            c: c,
                            onTap: () => _pickTime(isOpen: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _timeTile(
                            label: 'Closes At',
                            time: _closeTime,
                            icon: Icons.nights_stay_rounded,
                            color: Colors.indigo,
                            c: c,
                            onTap: () => _pickTime(isOpen: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('LOCATION', c),
                    _field(
                      controller: _addressCtrl,
                      label: 'Street Address',
                      icon: Icons.location_on_rounded,
                      c: c,
                      maxLines: 2,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _latCtrl,
                            label: 'Latitude',
                            icon: Icons.my_location_rounded,
                            c: c,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            validator: (v) => double.tryParse(v ?? '') == null
                                ? 'Invalid'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            controller: _lngCtrl,
                            label: 'Longitude',
                            icon: Icons.my_location_rounded,
                            c: c,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            validator: (v) => double.tryParse(v ?? '') == null
                                ? 'Invalid'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _fetchingGps ? null : _useGps,
                      icon: _fetchingGps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary),
                            )
                          : const Icon(Icons.gps_fixed_rounded,
                              color: AppColors.primary, size: 18),
                      label: Text(
                        _fetchingGps ? 'Detecting…' : 'Use Current GPS Location',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // ── save button ───────────────────────────────────────
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Save Changes',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, DhavColors c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.textHint,
                letterSpacing: 1.5)),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required DhavColors c,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: GoogleFonts.inter(fontSize: 14, color: c.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 13, color: c.textHint),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          filled: true,
          fillColor: c.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.red, width: 1.5),
          ),
        ),
      );

  Widget _timeTile({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required Color color,
    required DhavColors c,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.textHint)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                time.format(context),
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text('Tap to change',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: color)),
            ],
          ),
        ),
      );
}
