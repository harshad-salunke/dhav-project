import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/models/catalog_item.dart';
import '../../core/widgets/admin_sidebar.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _search = '';
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          const AdminSidebar(),
          const VerticalDivider(color: AppColors.border, width: 1),
          Expanded(
            child: Consumer<CatalogProvider>(
              builder: (context, provider, _) {
                final filtered = provider.items.where((item) {
                  final matchesSearch = _search.isEmpty ||
                      item.name.toLowerCase().contains(_search.toLowerCase()) ||
                      item.nameHindi.toLowerCase().contains(_search.toLowerCase()) ||
                      item.nameMarathi.toLowerCase().contains(_search.toLowerCase());
                  final matchesCat = _filterCategory == null ||
                      item.category == _filterCategory;
                  return matchesSearch && matchesCat;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CatalogHeader(
                      provider: provider,
                      categories: provider.categories,
                      selectedCategory: _filterCategory,
                      onSearch: (v) => setState(() => _search = v),
                      onCategoryFilter: (v) =>
                          setState(() => _filterCategory = v),
                      onAdd: () => _showItemDialog(context, provider),
                    ),
                    Expanded(
                      child: provider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.orange))
                          : _CatalogTable(
                              items: filtered,
                              provider: provider,
                              onEdit: (item) =>
                                  _showItemDialog(context, provider, item: item),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDialog(BuildContext context, CatalogProvider provider,
      {AdminCatalogItem? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CatalogItemDialog(
        provider: provider,
        existing: item,
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  final CatalogProvider provider;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCategoryFilter;
  final VoidCallback onAdd;

  const _CatalogHeader({
    required this.provider,
    required this.categories,
    required this.selectedCategory,
    required this.onSearch,
    required this.onCategoryFilter,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Catalog Management',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  Text('${provider.items.length} items in catalog',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              const Spacer(),
              // Show inactive toggle
              Row(
                children: [
                  Switch(
                    value: provider.showInactive,
                    onChanged: (_) => provider.toggleShowInactive(),
                    activeColor: AppColors.orange,
                  ),
                  Text('Show inactive',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 220,
                child: TextField(
                  onChanged: onSearch,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.textMuted, size: 16),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ChipFilter(
                    label: 'All',
                    active: selectedCategory == null,
                    onTap: () => onCategoryFilter(null)),
                ...categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _ChipFilter(
                          label: cat,
                          active: selectedCategory == cat,
                          onTap: () => onCategoryFilter(
                              selectedCategory == cat ? null : cat)),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipFilter extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ChipFilter(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.orange : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.orange : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: active ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _CatalogTable extends StatelessWidget {
  final List<AdminCatalogItem> items;
  final CatalogProvider provider;
  final void Function(AdminCatalogItem) onEdit;

  const _CatalogTable(
      {required this.items, required this.provider, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
          child: Text('No items found',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 14)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _TableHeader(),
            const Divider(color: AppColors.border, height: 1),
            ...items.map((item) =>
                _ItemRow(item: item, provider: provider, onEdit: onEdit)),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('CATEGORY', style: style)),
          Expanded(child: Text('UNIT', style: style)),
          Expanded(child: Text('STATUS', style: style)),
          SizedBox(width: 100, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final AdminCatalogItem item;
  final CatalogProvider provider;
  final void Function(AdminCatalogItem) onEdit;

  const _ItemRow(
      {required this.item, required this.provider, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Name column
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  if (item.nameMarathi.isNotEmpty || item.nameHindi.isNotEmpty)
                    Text(
                        [if (item.nameMarathi.isNotEmpty) item.nameMarathi,
                          if (item.nameHindi.isNotEmpty) item.nameHindi]
                            .join(' / '),
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            // Category
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.category,
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
            ),
            // Unit
            Expanded(
              child: Text(item.unit,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            // Status
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.isActive
                      ? AppColors.green.withValues(alpha: 0.1)
                      : AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.inter(
                      color: item.isActive ? AppColors.green : AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: 100,
              child: Row(
                children: [
                  _ActionBtn(
                    icon: Icons.edit_rounded,
                    color: AppColors.orange,
                    tooltip: 'Edit',
                    onTap: () => onEdit(item),
                  ),
                  _ActionBtn(
                    icon: item.isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: item.isActive ? AppColors.yellow : AppColors.green,
                    tooltip: item.isActive ? 'Deactivate' : 'Activate',
                    onTap: () => provider.toggleActive(item.itemId, !item.isActive),
                  ),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.red,
                    tooltip: 'Delete',
                    onTap: () => _confirmDelete(context, item),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AdminCatalogItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete "${item.name}"?',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
            'This will deactivate the item so it no longer appears in customer searches.',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.deleteItem(item.itemId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onTap,
        splashRadius: 18,
      ),
    );
  }
}

// ── Add / Edit Dialog ──────────────────────────────────────────────────────────

class _CatalogItemDialog extends StatefulWidget {
  final CatalogProvider provider;
  final AdminCatalogItem? existing;

  const _CatalogItemDialog({required this.provider, this.existing});

  @override
  State<_CatalogItemDialog> createState() => _CatalogItemDialogState();
}

class _CatalogItemDialogState extends State<_CatalogItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _nameHindi;
  late TextEditingController _nameMarathi;
  late TextEditingController _category;
  late TextEditingController _unit;
  late TextEditingController _imageUrl;
  bool _saving = false;

  static const _commonCategories = [
    'Grains', 'Oil & Ghee', 'Dairy', 'Snacks', 'Personal Care',
    'Cleaning', 'Baby Care', 'Beverages', 'Spices', 'Frozen Foods',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _nameHindi = TextEditingController(text: e?.nameHindi ?? '');
    _nameMarathi = TextEditingController(text: e?.nameMarathi ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _unit = TextEditingController(text: e?.unit ?? '');
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _nameHindi.dispose();
    _nameMarathi.dispose();
    _category.dispose();
    _unit.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit Item' : 'Add Catalog Item',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                _Field(label: 'Name (English) *', controller: _name,
                    validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _Field(
                            label: 'Name (Hindi)', controller: _nameHindi)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _Field(
                            label: 'Name (Marathi)', controller: _nameMarathi)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field(
                            label: 'Category *',
                            controller: _category,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: _commonCategories
                                .map((cat) => ActionChip(
                                      label: Text(cat,
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppColors.textSecondary)),
                                      backgroundColor: AppColors.card,
                                      side: const BorderSide(
                                          color: AppColors.border),
                                      padding: const EdgeInsets.all(2),
                                      onPressed: () =>
                                          setState(() => _category.text = cat),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                          label: 'Unit * (e.g. 1kg, 500ml, 1pc)',
                          controller: _unit,
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                    label: 'Image URL (optional)',
                    controller: _imageUrl),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Save Changes' : 'Add Item'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = {
      'name': _name.text.trim(),
      'name_hindi': _nameHindi.text.trim(),
      'name_marathi': _nameMarathi.text.trim(),
      'category': _category.text.trim(),
      'unit': _unit.text.trim(),
      'image_url': _imageUrl.text.trim(),
    };
    bool ok;
    if (widget.existing != null) {
      ok = await widget.provider.updateItem(widget.existing!.itemId, payload);
    } else {
      ok = await widget.provider.createItem(payload);
    }
    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.pop(context);
    }
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _Field(
      {required this.label, required this.controller, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          validator: validator,
          style:
              GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.orange)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.red)),
          ),
        ),
      ],
    );
  }
}
