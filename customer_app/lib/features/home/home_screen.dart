import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/models/catalog_item.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/dhav_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _areaName = 'Detecting location…';
  String? _selectedCategory;
  bool _locating = true;

  static const _categories = [
    ('🌾', 'Grains'),
    ('🫙', 'Oil'),
    ('🥛', 'Dairy'),
    ('🍟', 'Snacks'),
    ('🧴', 'Personal Care'),
    ('🧹', 'Cleaning'),
    ('👶', 'Baby Care'),
  ];

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      // Simple area detection via coordinates
      // In production, use Google Geocoding API
      setState(() {
        _areaName = 'Kothrud, Pune';
        _locating = false;
      });
      if (mounted) {
        context.read<CatalogProvider>().loadCatalog(
            lat: pos.latitude, lng: pos.longitude);
      }
    } catch (_) {
      setState(() {
        _areaName = 'Pune';
        _locating = false;
      });
      if (mounted) context.read<CatalogProvider>().loadCatalog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final catalog = context.watch<CatalogProvider>();
    final cart = context.watch<CartProvider>();
    final orders = context.watch<OrderProvider>();

    final featured = catalog.items.where((i) => i.isAvailable).take(6).toList();
    final filtered = _selectedCategory == null
        ? featured
        : catalog.items
            .where((i) =>
                i.isAvailable &&
                i.category.toLowerCase() ==
                    _selectedCategory!.toLowerCase())
            .take(6)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(auth),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _detectLocation,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildSearchBar()),
                    if (orders.hasActiveOrder)
                      SliverToBoxAdapter(child: _buildTrackBanner(orders)),
                    SliverToBoxAdapter(child: _buildCategoryChips()),
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Order Again',
                            onSeeAll: () => Navigator.pushNamed(
                                context, '/orders'))),
                    SliverToBoxAdapter(
                        child: _buildOrderAgainRow(catalog.items)),
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Fresh For You')),
                    if (catalog.loading)
                      const SliverToBoxAdapter(
                          child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
                      ))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildItemCard(filtered[index], cart),
                            childCount: filtered.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Trending Near You')),
                    SliverToBoxAdapter(
                        child: _buildTrendingRow(catalog.items)),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DhavBottomNav(currentIndex: 0),
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () {/* TODO: address picker */},
              child: Row(
                children: [
                  Text(
                    _locating ? 'Detecting location…' : _areaName,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/notifications'),
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary, size: 26),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.error, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                (auth.user?.name.isNotEmpty == true
                        ? auth.user!.name[0]
                        : 'U')
                    .toUpperCase(),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/search'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: AppColors.textHint, size: 20),
            const SizedBox(width: 10),
            Text(
              'Search dal, rice, oil…',
              style: GoogleFonts.inter(
                  color: AppColors.textHint, fontSize: 14),
            ),
            const Spacer(),
            const Icon(Icons.mic_outlined,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackBanner(OrderProvider orders) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/order-tracking',
          arguments: {'order_id': orders.activeOrder!.orderId}),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Order in progress • Track Now 🛵',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final (emoji, name) = _categories[i];
          final selected = _selectedCategory == name;
          return GestureDetector(
            onTap: () =>
                setState(() => _selectedCategory = selected ? null : name),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                '$emoji $name',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          if (onSeeAll != null) ...[
            const Spacer(),
            GestureDetector(
              onTap: onSeeAll,
              child: Text('See all',
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

  Widget _buildOrderAgainRow(List<CatalogItem> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('No recent orders',
            style: GoogleFonts.inter(
                color: AppColors.textHint, fontSize: 13)),
      );
    }
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.take(6).length,
        itemBuilder: (context, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => context.read<CartProvider>().addItem(item),
            child: Container(
              width: 110,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      child: item.imageUrl != null
                          ? Image.network(item.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => _itemPlaceholder())
                          : _itemPlaceholder(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (item.price != null)
                          Text('₹${item.price!.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(CatalogItem item, CartProvider cart) {
    final qty = cart.quantityOf(item.id);
    final badgeColor = _categoryBadgeColor(item.category);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with category badge
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
                          errorBuilder: (_, __, ___) => _itemPlaceholderLarge())
                      : _itemPlaceholderLarge(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.category.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Expanded(
            flex: 2,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      // Add/quantity button
                      if (qty == 0)
                        GestureDetector(
                          onTap: () => cart.addItem(item),
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
                            _qtyBtn(Icons.remove,
                                () => cart.removeItem(item.id)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('$qty',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                            ),
                            _qtyBtn(Icons.add, () => cart.addItem(item)),
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

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      );

  Widget _buildTrendingRow(List<CatalogItem> items) {
    final trending = items.skip(6).take(5).toList();
    if (trending.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Center(
            child: Text('Items loading…',
                style: GoogleFonts.inter(
                    color: AppColors.textHint, fontSize: 13)),
          ),
        ),
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: trending.length,
        itemBuilder: (_, i) {
          final item = trending[i];
          return Container(
            width: 90,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: item.imageUrl != null
                        ? Image.network(item.imageUrl!,
                            fit: BoxFit.cover, width: double.infinity,
                            errorBuilder: (_, __, ___) => _itemPlaceholder())
                        : _itemPlaceholder(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(item.name,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemPlaceholder() => Container(
        color: AppColors.primaryLight,
        child: const Center(
            child: Icon(Icons.shopping_basket_outlined,
                color: AppColors.primary, size: 24)),
      );

  Widget _itemPlaceholderLarge() => Container(
        color: AppColors.primaryLight,
        child: const Center(
            child: Icon(Icons.shopping_basket_outlined,
                color: AppColors.primary, size: 40)),
      );

  Color _categoryBadgeColor(String category) {
    switch (category.toLowerCase()) {
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
}
