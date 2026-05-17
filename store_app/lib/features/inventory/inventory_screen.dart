import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/catalog_item.dart';
import '../../core/providers/inventory_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final store = context.read<StoreProvider>();
    final inventory = context.read<InventoryProvider>();
    if (store.store == null) {
      await store.loadMyStore();
    }
    final initial = store.store?.availableItemIds ?? const <String>[];
    await inventory.load(initialAvailable: initial);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<InventoryProvider>().saveToBackend();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Inventory saved')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inv = context.watch<InventoryProvider>();

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
        title: Text('Inventory',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('SAVE',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.divider, width: 1),
                  ),
                  child: TextField(
                    onChanged: (v) => inv.setSearch(v),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon:
                          Icon(Icons.search_rounded, color: c.textHint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: inv.categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final all = i == 0;
                      final category = all ? null : inv.categories[i - 1];
                      final isSelected = inv.activeCategory == category;
                      return ChoiceChip(
                        label: Text(all ? 'All' : category!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        selected: isSelected,
                        onSelected: (_) => inv.setCategory(category),
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        backgroundColor: c.card,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color: isSelected ? AppColors.primary : c.divider,
                              width: isSelected ? 1.5 : 1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                _StatCard(label: 'Catalog', value: '${inv.catalog.length}', c: c),
                const SizedBox(width: 10),
                _StatCard(
                    label: 'Available',
                    value: '${inv.available.length}',
                    color: AppColors.green,
                    c: c),
              ],
            ),
          ),
          Expanded(
            child: inv.loading
                ? const Center(child: CircularProgressIndicator())
                : inv.error != null
                    ? Center(
                        child: Text(inv.error!,
                            style: GoogleFonts.inter(color: AppColors.red)))
                    : inv.catalog.isEmpty
                        ? Center(
                            child: Text('No products found',
                                style: GoogleFonts.inter(color: c.textHint)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: inv.catalog.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final item = inv.catalog[i];
                              return _InventoryItem(
                                item: item,
                                c: c,
                                isAvailable: inv.available.contains(item.itemId),
                                onToggle: () => inv.toggleLocal(item.itemId),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final DhavColors c;

  const _StatCard(
      {required this.label, required this.value, this.color, required this.c});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color != null ? color!.withValues(alpha: 0.08) : c.card,
          borderRadius: BorderRadius.circular(14),
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
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: c.textHint)),
          ],
        ),
      ),
    );
  }
}

class _InventoryItem extends StatelessWidget {
  final CatalogItem item;
  final DhavColors c;
  final bool isAvailable;
  final VoidCallback onToggle;

  const _InventoryItem({
    required this.item,
    required this.c,
    required this.isAvailable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isAvailable
                ? AppColors.green.withValues(alpha: 0.4)
                : c.divider,
            width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.textMedium, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Text('${item.category} • ${item.unit}',
                    style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
                if (item.price > 0) ...[
                  const SizedBox(height: 4),
                  Text('₹${item.price.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppColors.green,
          ),
        ],
      ),
    );
  }
}
