import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/store.dart';
import '../../core/providers/store_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';

class StoreTeamScreen extends StatefulWidget {
  const StoreTeamScreen({super.key});

  @override
  State<StoreTeamScreen> createState() => _StoreTeamScreenState();
}

class _StoreTeamScreenState extends State<StoreTeamScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await context.read<StoreProvider>().loadDeliveryBoys();
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addMember() async {
    final storeProv = context.read<StoreProvider>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AddMemberDialog(),
    );
    if (result == null) return;
    try {
      await storeProv.addDeliveryBoy(
        name: result['name']!,
        phone: result['phone']!,
        googleAccountEmail: result['email']!,
      );
      if (mounted) _toast('Delivery partner added');
    } catch (e) {
      if (mounted) _toast('Failed to add: $e');
    }
  }

  Future<void> _remove(DeliveryBoy boy) async {
    final storeProv = context.read<StoreProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${boy.name}?'),
        content: const Text('They will no longer be able to accept deliveries.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await storeProv.removeDeliveryBoy(boy.deliveryBoyId);
      if (mounted) _toast('Removed');
    } catch (e) {
      if (mounted) _toast('Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final boys = context.watch<StoreProvider>().deliveryBoys;
    final active = boys.where((b) => b.currentOrderId == null && b.isActive).length;
    final onDelivery = boys.where((b) => b.currentOrderId != null).length;

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
        title: Text('Delivery Team',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: c.textPrimary, size: 26),
            onPressed: _addMember,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _TeamStat(label: 'Total', value: '${boys.length}', c: c),
                  const SizedBox(width: 10),
                  _TeamStat(
                      label: 'Available',
                      value: '$active',
                      color: AppColors.green,
                      c: c),
                  const SizedBox(width: 10),
                  _TeamStat(
                      label: 'On Delivery',
                      value: '$onDelivery',
                      color: AppColors.primary,
                      c: c),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const TeamListShimmer()
                  : boys.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 60),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.group_outlined,
                                      size: 48, color: c.textHint),
                                  const SizedBox(height: 12),
                                  Text('No delivery partners yet',
                                      style: GoogleFonts.inter(
                                          fontSize: 15, color: c.textHint)),
                                  const SizedBox(height: 8),
                                  Text('Tap + to add one.',
                                      style: GoogleFonts.inter(
                                          fontSize: 13, color: c.textHint)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: boys.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _TeamMemberCard(
                            boy: boys[i],
                            c: c,
                            onRemove: () => _remove(boys[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Delivery Partner',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Phone', border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Google Account Email',
                    helperText: 'Used to sign in to the DHAV app',
                    border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          Navigator.pop(context, {
                            'name': _name.text.trim(),
                            'phone': _phone.text.trim(),
                            'email': _email.text.trim(),
                          });
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final DhavColors c;
  const _TeamStat(
      {required this.label, required this.value, this.color, required this.c});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color != null ? color!.withValues(alpha: 0.08) : c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color != null ? color!.withValues(alpha: 0.2) : c.divider,
              width: 1),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
            Text(label,
                style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
          ],
        ),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final DeliveryBoy boy;
  final DhavColors c;
  final VoidCallback onRemove;

  const _TeamMemberCard(
      {required this.boy, required this.c, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final onDelivery = boy.currentOrderId != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.divider, width: 1)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(
                boy.name.isEmpty
                    ? '?'
                    : boy.name.split(' ').map((e) => e.isEmpty ? '' : e[0]).take(2).join(),
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(boy.name,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                Text(boy.phone,
                    style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                Text(boy.googleAccountEmail,
                    style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: (onDelivery ? AppColors.primary : AppColors.green)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(onDelivery ? 'On Delivery' : 'Available',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              onDelivery ? AppColors.primary : AppColors.green)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.red, size: 22),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
