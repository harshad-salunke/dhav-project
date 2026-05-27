import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/catalog_item.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';

class StoreDetailScreen extends StatefulWidget {
  final Map<String, dynamic> storeSnippet;
  const StoreDetailScreen({super.key, required this.storeSnippet});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  List<CatalogItem> _items = [];
  Map<String, dynamic> _store = {};
  bool _loading = true;
  String? _error;
  String? _selectedCategory;

  String get _storeId => widget.storeSnippet['store_id'] as String? ?? '';
  String get _storeName =>
      widget.storeSnippet['name']?.toString() ?? 'Kirana Store';

  bool get _isActive =>
      (_store['is_active'] as bool? ??
          widget.storeSnippet['is_active'] as bool? ??
          false) &&
      !(_store['is_suspended'] as bool? ??
          widget.storeSnippet['is_suspended'] as bool? ??
          false);

  List<String> get _categories {
    final cats = _items.map((i) => i.category).toSet().toList()..sort();
    return cats;
  }

  List<CatalogItem> get _filtered => _selectedCategory == null
      ? _items
      : _items
          .where((i) =>
              i.category.toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiClient.get('/catalog/stores/$_storeId');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _store = (body['store'] as Map<String, dynamic>?) ?? {};
            final rawItems = (body['items'] as List?) ?? [];
            _items = rawItems
                .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
                .toList();
            _loading = false;
          });
        }
      } else {
        throw Exception('Server error ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final dist = (widget.storeSnippet['distance_km'] as num?)?.toDouble();
    final verified = widget.storeSnippet['is_verified'] as bool? ?? false;
    final rating =
        (_store['rating'] as num?)?.toDouble() ?? 0.0;
    final area =
        (_store['area'] ?? widget.storeSnippet['area'] ?? '') as String;
    final totalItems = _items.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(
            context,
            dist: dist,
            verified: verified,
            rating: rating,
            area: area,
            totalItems: totalItems,
          ),
          if (!_loading && !_isActive) _InactiveBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: cart.itemCount > 0 && cart.storeId == _storeId
          ? _CartBar(
              cart: cart,
              storeName: _storeName,
              onViewCart: () => Navigator.pushNamed(context, '/cart'),
            )
          : null,
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required double? dist,
    required bool verified,
    required double rating,
    required String area,
    required int totalItems,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top row: back + refresh
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadStore,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 20, color: Colors.white),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            // Store info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _storeName,
                                style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha:0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Verified',
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (area.isNotEmpty)
                              _infoPill(Icons.location_on_outlined, area),
                            if (dist != null)
                              _infoPill(Icons.near_me_outlined,
                                  '${dist.toStringAsFixed(1)} km'),
                            if (rating > 0)
                              _infoPill(Icons.star_rounded,
                                  rating.toStringAsFixed(1)),
                            if (!_loading && totalItems > 0)
                              _infoPill(Icons.inventory_2_outlined,
                                  '$totalItems items'),
                            _statusPill(_isActive),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Category chips (only when items are loaded)
            if (!_loading && _categories.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final sel = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() =>
                          _selectedCategory =
                              cat == _selectedCategory ? null : cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? Colors.white
                              : Colors.white.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.white
                                  .withValues(alpha:sel ? 1 : 0.4)),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? AppColors.primary
                                    : Colors.white)),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white.withValues(alpha:0.85)),
        const SizedBox(width: 3),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha:0.9),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _statusPill(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha:0.25)
            : Colors.black.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF4ADE80)
                  : Colors.white.withValues(alpha:0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(isActive ? 'Open' : 'Closed',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const StoreDetailShimmer();
    if (_error != null) return _buildError();
    if (_filtered.isEmpty) return _buildEmpty();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
        key: ValueKey(_filtered[i].id),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 140 + (i % 6) * 40),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child:
              Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
        ),
        child: _StoreItemCard(
          item: _filtered[i],
          storeId: _storeId,
          storeName: _storeName,
          isStoreActive: _isActive,
        ),
      ),
    );
  }

  // _buildShimmerGrid replaced by StoreDetailShimmer from shimmer_widgets.dart

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load store',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(_error!,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            _selectedCategory != null
                ? 'No $_selectedCategory items'
                : 'No items listed yet',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedCategory != null
                ? 'Try a different category'
                : "This store hasn't set up its inventory",
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Inactive banner ───────────────────────────────────────────────────────────

class _InactiveBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This store is currently inactive. Browsing only — ordering unavailable.',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cart bar ──────────────────────────────────────────────────────────────────

class _CartBar extends StatelessWidget {
  final CartProvider cart;
  final String storeName;
  final VoidCallback onViewCart;

  const _CartBar({
    required this.cart,
    required this.storeName,
    required this.onViewCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${cart.itemCount}',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cart.itemCount} item${cart.itemCount != 1 ? 's' : ''} • ₹${cart.subtotal.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                Text('from $storeName',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onViewCart,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha:0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Text('View Cart',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item card ──────────────────────────────────────────────────────────────────

class _StoreItemCard extends StatelessWidget {
  final CatalogItem item;
  final String storeId;
  final String storeName;
  final bool isStoreActive;

  const _StoreItemCard({
    required this.item,
    required this.storeId,
    required this.storeName,
    required this.isStoreActive,
  });

  void _handleAdd(BuildContext context) {
    if (!isStoreActive) return;
    final cart = context.read<CartProvider>();
    if (cart.itemCount > 0 &&
        cart.storeId != null &&
        cart.storeId != storeId) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Replace cart?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Text(
              'Your cart has items from ${cart.storeName}.\nSwitch to $storeName and clear current cart?',
              style: GoogleFonts.inter()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep current')),
            TextButton(
              onPressed: () {
                cart.clearForNewStore();
                cart.setStore(storeId, storeName);
                cart.addItem(item);
                Navigator.pop(context);
              },
              child: Text('Switch',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    } else {
      if (cart.storeId == null) cart.setStore(storeId, storeName);
      cart.addItem(item);
    }
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'grains':
        return AppColors.badgeGrains;
      case 'dairy':
        return AppColors.badgeDairy;
      case 'snacks':
        return AppColors.badgeSnacks;
      default:
        return AppColors.badgeFresh;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(item.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: item.imageUrl != null
                      ? Image.network(item.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _categoryColor(item.category),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(item.category.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  Text(item.unit,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const Spacer(),
                  Row(
                    children: [
                      if (item.price != null)
                        Text('₹${item.price!.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      const Spacer(),
                      if (!isStoreActive)
                        const Icon(Icons.block_rounded,
                            size: 20, color: AppColors.textHint)
                      else if (qty == 0)
                        GestureDetector(
                          onTap: () => _handleAdd(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 18),
                          ),
                        )
                      else
                        Row(
                          children: [
                            _qtyBtn(Icons.remove, () =>
                                context.read<CartProvider>().removeItem(item.id)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: Text('$qty',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                            ),
                            _qtyBtn(
                                Icons.add, () => _handleAdd(context)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.primaryLight,
        child: const Center(
            child: Icon(Icons.shopping_basket_outlined,
                color: AppColors.primary, size: 40)),
      );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      );
}
