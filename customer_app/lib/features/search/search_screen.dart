import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/catalog_item.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/dhav_bottom_nav.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final cart = context.watch<CartProvider>();
    final results = catalog.search(_query, category: _selectedCategory);
    final categories = ['All Results', ...catalog.categoryNames];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search dal, rice, oil…',
                          hintStyle: GoogleFonts.inter(
                              color: AppColors.textHint, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppColors.textHint),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      color: AppColors.textHint, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Category filter chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  final isAll = cat == 'All Results';
                  final selected = isAll
                      ? _selectedCategory == null
                      : _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _selectedCategory = isAll ? null : cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color:
                            selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border),
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.divider),

            // Results list
            Expanded(
              child: results.isEmpty && _query.isNotEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, i) =>
                          _buildItemRow(results[i], cart),
                    ),
            ),
          ],
        ),
      ),
      // Floating cart bar
      bottomNavigationBar: cart.isEmpty
          ? const DhavBottomNav(currentIndex: 1)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CartBar(cart: cart),
                const DhavBottomNav(currentIndex: 1),
              ],
            ),
    );
  }

  Widget _buildItemRow(CatalogItem item, CartProvider cart) {
    final qty = cart.quantityOf(item.id);
    final available = item.isAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              color: AppColors.primaryLight,
              child: item.imageUrl != null
                  ? Image.network(item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.shopping_basket_outlined,
                          color: AppColors.primary))
                  : const Icon(Icons.shopping_basket_outlined,
                      color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!available)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('NOT AVAILABLE',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                            letterSpacing: 0.5)),
                  ),
                Text(item.name,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: available
                            ? AppColors.textPrimary
                            : AppColors.textHint)),
                Text('${item.category} • ${item.unit}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                if (item.price != null)
                  Text('₹${item.price!.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
              ],
            ),
          ),
          // Add/remove
          if (!available)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text('Sold Out',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            )
          else if (qty == 0)
            ElevatedButton(
              onPressed: () => cart.addItem(item),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text('Add to Cart',
                  style: GoogleFonts.inter(fontSize: 13)),
            )
          else
            Row(
              children: [
                _qtyBtn(Icons.remove, () => cart.removeItem(item.id)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$qty',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                _qtyBtn(Icons.add, () => cart.addItem(item)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text('Nothing found',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              "We couldn't find matches for this search. Try browsing categories or checking spelling.",
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final CartProvider cart;
  const _CartBar({required this.cart});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/cart'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cart.itemCount} ITEMS',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                Text('₹${cart.subtotal.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            Text('View Cart >',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
