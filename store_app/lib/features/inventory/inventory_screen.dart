import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/constants/app_routes.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Groceries', 'Beverages', 'Snacks', 'Household', 'Personal Care'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        title: Text('Inventory', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.primary,
              unselectedLabelColor: c.textHint,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Stock'),
                Tab(text: 'Low Stock'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                // Search Bar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.divider, width: 1),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search_rounded, color: c.textHint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Category Chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final category = _categories[i];
                      final isSelected = _selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedCategory = category),
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                        backgroundColor: c.card,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? AppColors.primary : c.divider, width: isSelected ? 1.5 : 1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Inventory Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                _StatCard(label: 'Total Items', value: '128', c: c),
                const SizedBox(width: 10),
                _StatCard(label: 'In Stock', value: '112', color: AppColors.green, c: c),
                const SizedBox(width: 10),
                _StatCard(label: 'Low Stock', value: '16', color: Colors.orange, c: c),
              ],
            ),
          ),

          // Inventory List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _InventoryList(inventory: _inStockItems, c: c, isLowStock: false),
                _InventoryList(inventory: _lowStockItems, c: c, isLowStock: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.addProduct),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final DhavColors c;

  const _StatCard({required this.label, required this.value, this.color, required this.c});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color != null ? color!.withValues(alpha: 0.08) : c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color != null ? color!.withValues(alpha: 0.2) : c.divider, width: 1),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: c.textHint)),
          ],
        ),
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  final List<Map<String, dynamic>> inventory;
  final DhavColors c;
  final bool isLowStock;

  const _InventoryList({required this.inventory, required this.c, required this.isLowStock});

  @override
  Widget build(BuildContext context) {
    if (inventory.isEmpty) {
      return Center(child: Text('No products found', style: GoogleFonts.inter(color: c.textHint)));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: inventory.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _InventoryItem(item: inventory[i], c: c, isLowStock: isLowStock),
    );
  }
}

class _InventoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final DhavColors c;
  final bool isLowStock;

  const _InventoryItem({required this.item, required this.c, required this.isLowStock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isLowStock ? Colors.orange.withValues(alpha: 0.3) : c.divider, width: 1),
      ),
      child: Row(
        children: [
          // Product Image Placeholder
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textMedium,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item['name'] as String, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    if (isLowStock) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('LOW', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.orange)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(item['category'] as String, style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text('${item['stock']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary)),
                          Text(' in stock', style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
                        ],
                      ),
                    ),
                    if (isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Reorder: ${item['reorderLevel']}', style: GoogleFonts.inter(fontSize: 11, color: Colors.orange)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '₹${item['price']}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              IconButton(
                onPressed: () => _showEditDialog(context, item),
                icon: Icon(Icons.edit_rounded, color: c.textHint, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => _ProductEditDialog(product: item),
    );
  }
}

class _ProductEditDialog extends StatefulWidget {
  final Map<String, dynamic> product;

  const _ProductEditDialog({required this.product});

  @override
  State<_ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<_ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _reorderLevelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.product['name'] ?? '';
    _priceController.text = widget.product['price']?.toString() ?? '';
    _stockController.text = widget.product['stock']?.toString() ?? '';
    _categoryController.text = widget.product['category'] ?? '';
    _reorderLevelController.text = widget.product['reorderLevel']?.toString() ?? '10';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _reorderLevelController.dispose();
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Edit Product', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: c.textHint),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _nameController,
                label: 'Product Name',
                icon: Icons.inventory_2_rounded,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _priceController,
                label: 'Selling Price',
                icon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _stockController,
                      label: 'Current Stock',
                      icon: Icons.storage_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _reorderLevelController,
                      label: 'Reorder Level',
                      icon: Icons.warning_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _categoryController,
                label: 'Category',
                icon: Icons.category_rounded,
              ),
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
                        if (_formKey.currentState?.validate() ?? false) {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated')));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: Text('Save Changes', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
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

final _inStockItems = [
  {'id': 1, 'name': 'Tata Salt 1kg', 'category': 'Groceries', 'stock': 45, 'price': 25, 'reorderLevel': 10},
  {'id': 2, 'name': 'Amul Butter 100g', 'category': 'Dairy', 'stock': 32, 'price': 60, 'reorderLevel': 15},
  {'id': 3, 'name': 'Fortune Oil 1L', 'category': 'Cooking', 'stock': 28, 'price': 175, 'reorderLevel': 20},
  {'id': 4, 'name': 'Dettol Soap', 'category': 'Personal Care', 'stock': 55, 'price': 35, 'reorderLevel': 20},
  {'id': 5, 'name': 'Lays Chips', 'category': 'Snacks', 'stock': 40, 'price': 20, 'reorderLevel': 25},
  {'id': 6, 'name': 'Colgate 100g', 'category': 'Personal Care', 'stock': 38, 'price': 95, 'reorderLevel': 15},
  {'id': 7, 'name': 'Maggi 500g', 'category': 'Snacks', 'stock': 60, 'price': 70, 'reorderLevel': 30},
  {'id': 8, 'name': 'Aashirvaad Atta 5kg', 'category': 'Groceries', 'stock': 22, 'price': 280, 'reorderLevel': 15},
];

final _lowStockItems = [
  {'id': 9, 'name': 'Rice 5kg', 'category': 'Groceries', 'stock': 5, 'price': 250, 'reorderLevel': 10},
  {'id': 10, 'name': 'Wheat 5kg', 'category': 'Groceries', 'stock': 3, 'price': 220, 'reorderLevel': 10},
  {'id': 11, 'name': 'Sugar 1kg', 'category': 'Groceries', 'stock': 4, 'price': 45, 'reorderLevel': 15},
  {'id': 12, 'name': 'Tea 500g', 'category': 'Beverages', 'stock': 8, 'price': 120, 'reorderLevel': 15},
];
