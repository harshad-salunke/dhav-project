import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/catalog_item.dart';
import '../../core/utils/lottie_utils.dart';
import '../../core/providers/address_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/main_shell.dart';
import '../address/address_selection_sheet.dart';
import '../catalog/item_detail_screen.dart';
import 'hero_banner.dart';
import 'store_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  String _areaName = 'Detecting location…';
  bool _locating = true;
  int _mode = 0;
  late final PageController _pageCtrl = PageController();

  // Gradient shimmer
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  // Search bar scooter
  late final AnimationController _scooterCtrl;
  late final Animation<double> _scooterAnim;
  late final Animation<double> _scooterFade;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final catalog = context.read<CatalogProvider>();
      if (catalog.loadedOnce && catalog.hasLocation) {
        // Reuse cached location/catalog — no GPS lookup, no API call.
        setState(() {
          _areaName = catalog.areaName ?? 'Pune';
          _locating = false;
        });
      } else {
        _detectLocation();
      }
      context.read<OrderProvider>().loadHistory();
      context.read<AddressProvider>().loadAddresses();
    });

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_shimmerCtrl);

    _scooterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _scooterAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scooterCtrl,
        curve: const Interval(0.0, 0.82, curve: Curves.easeInOut),
      ),
    );
    _scooterFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _scooterCtrl,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _shimmerCtrl.dispose();
    _scooterCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() => _mode = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _detectLocation({bool force = false}) async {
    setState(() {
      _areaName = 'Detecting location…';
      _locating = true;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _areaName = 'Location access denied';
          _locating = false;
        });
        if (mounted) {
          context.read<CatalogProvider>().loadCatalog(force: force);
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      final area = await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _areaName = area;
          _locating = false;
        });
        final catalog = context.read<CatalogProvider>();
        catalog.setAreaName(area);
        catalog.loadCatalog(
            lat: pos.latitude, lng: pos.longitude, force: force);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _areaName = 'Pune';
          _locating = false;
        });
        context.read<CatalogProvider>().loadCatalog(force: force);
      }
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=$lat&lon=$lng&zoom=15&addressdetails=1');
      final resp = await http.get(uri, headers: {
        'User-Agent': 'DHAVApp/1.0 (harshadsalunke2002@gmail.com)',
      }).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final area = addr['suburb'] ??
            addr['neighbourhood'] ??
            addr['village'] ??
            addr['town'] ??
            addr['city'] ??
            addr['county'] ??
            'Pune';
        final city =
            addr['city'] ?? addr['town'] ?? addr['state_district'] ?? '';
        return city.isNotEmpty && city != area
            ? '$area, $city'
            : area.toString();
      }
    } catch (_) {}
    return 'Pune';
  }

  void _openCategory(String emoji, String name, List<CatalogItem> allItems) {
    final catItems = allItems
        .where((i) => i.category.toLowerCase() == name.toLowerCase())
        .toList();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _CategoryBrowseScreen(
          emoji: emoji,
          category: name,
          items: catItems,
        ),
        transitionsBuilder: (_, anim, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return SlideTransition(position: slide, child: child);
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final catalog = context.watch<CatalogProvider>();
    final orders = context.watch<OrderProvider>();
    final allItems = catalog.items;
    final featured = allItems.take(12).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildGradientHeader(auth, catalog),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _mode = i),
                physics: const ClampingScrollPhysics(),
                children: [
                  // ── DHAV tab ──────────────────────────────────────────
                  RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => _detectLocation(force: true),
                    child: CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(child: HeroBanner()),
                        if (orders.hasActiveOrder)
                          SliverToBoxAdapter(
                              child: _buildTrackBanner(orders)),
                        SliverToBoxAdapter(
                            child: _buildCategoryChips(allItems)),
                        if (orders.loading) ...[
                          SliverToBoxAdapter(
                              child: _buildSectionHeader('Order Again',
                                  onSeeAll: () =>
                                      MainShell.of(context)?.switchTab(2))),
                          SliverToBoxAdapter(
                              child: _buildOrderAgainShimmer()),
                        ] else if (orders.orders.isNotEmpty) ...[
                          SliverToBoxAdapter(
                              child: _buildSectionHeader('Order Again',
                                  onSeeAll: () =>
                                      MainShell.of(context)?.switchTab(2))),
                          SliverToBoxAdapter(
                              child: _buildOrderAgainRow(orders)),
                        ],
                        SliverToBoxAdapter(
                            child: _buildSectionHeader('Fresh For You')),
                        if (catalog.loading)
                          _buildShimmerGrid()
                        else if (featured.isEmpty)
                          SliverToBoxAdapter(child: _buildNoStoresCard())
                        else ...[
                          if (catalog.hasLocation && catalog.storesFound == 0)
                            SliverToBoxAdapter(
                                child: _buildNoNearbyBanner()),
                          SliverPadding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    TweenAnimationBuilder<double>(
                                  key: ValueKey(featured[index].id),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                      milliseconds:
                                          180 + (index % 6) * 55),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, v, child) => Opacity(
                                    opacity: v,
                                    child: Transform.translate(
                                      offset: Offset(0, 18 * (1 - v)),
                                      child: child,
                                    ),
                                  ),
                                  child: _ItemCard(item: featured[index]),
                                ),
                                childCount: featured.length,
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
                        ],
                        SliverToBoxAdapter(
                            child: _buildSectionHeader('Trending Near You')),
                        SliverToBoxAdapter(
                            child: _buildTrendingRow(allItems)),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 20)),
                      ],
                    ),
                  ),
                  // ── Stores tab ────────────────────────────────────────
                  _NearbyStoresList(
                    catalog: catalog,
                    onStoreTap: (store) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StoreDetailScreen(storeSnippet: store),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildGradientHeader(AuthProvider auth, CatalogProvider catalog) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Gradient base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
                AppColors.background,
              ],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(auth),
              _buildModeTabs(catalog),
              _buildSearchBar(),
            ],
          ),
        ),
        // Animated shimmer sweep
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return Transform.translate(
                  offset: Offset(
                      (_shimmerAnim.value * 2.5 - 0.75) * w, 0),
                  child: Container(
                    width: w * 0.45,
                    height: 240,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x0DFFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final selectedAddr = context.watch<AddressProvider>().selected;
    final displayText = selectedAddr != null
        ? selectedAddr.displayTitle
        : (_locating ? 'Detecting location…' : _areaName);

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(16, statusBarH + 10, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => AddressSelectionSheet.show(context),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      displayText,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70, size: 18),
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
                    color: Colors.white, size: 26),
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
            onTap: () => MainShell.of(context)?.switchTab(3),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                (auth.user?.name.isNotEmpty == true
                        ? auth.user!.name[0]
                        : 'U')
                    .toUpperCase(),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs(CatalogProvider catalog) {
    final storeCount = catalog.allNearbyStores.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Stack(
        children: [
          // Animated white sliding pill
          AnimatedAlign(
            alignment: _mode == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tab labels
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(0),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 46,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _mode == 0
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.85),
                        ),
                        child: const Text('⚡  DHAV'),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(1),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 46,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _mode == 1
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.85),
                        ),
                        child: Text(
                          storeCount > 0
                              ? '🏪  Stores  $storeCount'
                              : '🏪  Stores',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => MainShell.of(context)?.switchTab(1),
      child: AnimatedBuilder(
        animation: _scooterCtrl,
        builder: (context, child) {
          final x = _scooterAnim.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              // Lottie delivery bike riding along the top border
              Positioned(
                top: -2,
                left: 20,
                right: 20,
                height: 40,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _scooterFade.value,
                    child: Align(
                      alignment: Alignment(x * 2 - 1, 0),
                      child: SizedBox(
                        width: 70,
                        height: 40,
                        child: Lottie.asset(
                          'assets/images/delivery_riding.lottie',
                          decoder: decodeDotLottie,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: Container(
          height: 52,
          margin: const EdgeInsets.fromLTRB(16, 38, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search dal, rice, oil…',
                    style: GoogleFonts.inter(
                        color: Colors.white60, fontSize: 14),
                  ),
                ),
                const Icon(Icons.mic_outlined,
                    color: Colors.white70, size: 20),
              ],
            ),
          ),
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

  /// Category chips — tap to open full-screen category browse with slide animation.
  Widget _buildCategoryChips(List<CatalogItem> allItems) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final (emoji, name) = _categories[i];
          return GestureDetector(
            onTap: () => _openCategory(emoji, name, allItems),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 3),
                  Text(name,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ],
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

  /// Shows real past-order items. Only called when orders.orders is non-empty.
  Widget _buildOrderAgainRow(OrderProvider orders) {
    final seen = <String>{};
    final pastItems = orders.orders
        .expand((o) => o.items)
        .where((item) => seen.add(item.itemId))
        .take(6)
        .toList();

    if (pastItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: pastItems.length,
        itemBuilder: (_, i) {
          final item = pastItems[i];
          return Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 3,
                    offset: Offset(0, 1))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14)),
                    ),
                    child: const Center(
                      child: Icon(Icons.shopping_basket_outlined,
                          color: AppColors.primary, size: 28),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (item.price != null)
                        Text('₹${item.price!.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderAgainShimmer() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFFE8E8E8),
          highlightColor: const Color(0xFFF5F5F5),
          child: Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, __) => Shimmer.fromColors(
            baseColor: const Color(0xFFE8E8E8),
            highlightColor: const Color(0xFFF5F5F5),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 11,
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 6)),
                          Container(
                              height: 9,
                              width: 55,
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 10)),
                          const Spacer(),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                  height: 13,
                                  width: 36,
                                  color: Colors.white),
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          childCount: 6,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
      ),
    );
  }

  Widget _buildNoNearbyBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.store_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No stores near you yet — browsing full catalogue',
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

  Widget _buildNoStoresCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.store_outlined,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'No stores near you yet',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'DHAV is expanding in your area!\nCheck back soon or pull down to refresh.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _detectLocation(force: true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ItemDetailScreen(item: item)),
            ),
            child: Container(
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
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: item.imageUrl != null
                          ? Image.network(item.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) =>
                                  _itemPlaceholder())
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
}

// ─── Category Browse Full-Screen ─────────────────────────────────────────────

class _CategoryBrowseScreen extends StatefulWidget {
  final String emoji;
  final String category;
  final List<CatalogItem> items;

  const _CategoryBrowseScreen({
    required this.emoji,
    required this.category,
    required this.items,
  });

  @override
  State<_CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends State<_CategoryBrowseScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CatalogItem> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items.where((i) =>
        i.name.toLowerCase().contains(q) ||
        (i.nameHindi?.toLowerCase().contains(q) ?? false) ||
        (i.nameMarathi?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: cart.itemCount > 0
          ? _CategoryCartBar(
              cart: cart,
              onViewCart: () => Navigator.pushNamed(context, '/cart'),
            )
          : null,
      body: Column(
        children: [
          // Gradient header
          Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back row + count badge
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _query.isEmpty
                                ? '${widget.items.length} items'
                                : '${filtered.length} of ${widget.items.length}',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Emoji + category name
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(widget.emoji,
                                style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.category,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1)),
                            const SizedBox(height: 3),
                            Text(
                              'Browse all ${widget.category.toLowerCase()} products',
                              style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Search bar inside the header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.search_rounded,
                              color: AppColors.textHint, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) =>
                                  setState(() => _query = v.trim()),
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary, fontSize: 14),
                              cursorColor: AppColors.primary,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                hintText:
                                    'Search in ${widget.category.toLowerCase()}…',
                                hintStyle: GoogleFonts.inter(
                                    color: AppColors.textHint, fontSize: 14),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(Icons.close_rounded,
                                    color: AppColors.textHint, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Items grid
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_query.isEmpty ? widget.emoji : '🔍',
                            style: const TextStyle(fontSize: 52)),
                        const SizedBox(height: 14),
                        Text(
                          _query.isEmpty
                              ? 'No ${widget.category} items yet'
                              : 'No results for "$_query"',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _query.isEmpty
                              ? 'Check back soon!'
                              : 'Try a different search term',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                        if (_query.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 9),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Clear search',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => TweenAnimationBuilder<double>(
                      key: ValueKey(filtered[i].id),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration:
                          Duration(milliseconds: 160 + (i % 6) * 40),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                            offset: Offset(0, 16 * (1 - v)),
                            child: child),
                      ),
                      child: _ItemCard(item: filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Cart Bar ────────────────────────────────────────────────────────

class _CategoryCartBar extends StatelessWidget {
  final CartProvider cart;
  final VoidCallback onViewCart;

  const _CategoryCartBar({required this.cart, required this.onViewCart});

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
              blurRadius: 16,
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
                  '${cart.itemCount} item${cart.itemCount != 1 ? 's' : ''} in cart',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                Text(
                  '₹${cart.subtotal.toStringAsFixed(0)} total',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
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
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View Cart',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Item Card Widget ─────────────────────────────────────────────────────────

class _ItemCard extends StatefulWidget {
  final CatalogItem item;
  const _ItemCard({required this.item});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _bounce() => _ctrl.forward().then((_) => _ctrl.reverse());

  Color _badgeColor(String cat) {
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
    final qty = cart.quantityOf(widget.item.id);
    final item = widget.item;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ItemDetailScreen(item: item),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow,
                blurRadius: 4,
                offset: Offset(0, 1))
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
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: Hero(
                      tag: 'item_img_${item.id}',
                      child: item.imageUrl != null
                          ? Image.network(
                              item.imageUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _imgPlaceholder(),
                            )
                          : _imgPlaceholder(),
                    ),
                  ),
                  if (!item.isAvailable)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.30),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_off_outlined,
                                    color: Colors.white, size: 11),
                                const SizedBox(width: 3),
                                Text(
                                  'Not near you',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _badgeColor(item.category),
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
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    const Spacer(),
                    Row(
                      children: [
                        if (item.price != null)
                          Text(
                            '₹${item.price!.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                        const Spacer(),
                        if (qty == 0)
                          ScaleTransition(
                            scale: _scale,
                            child: GestureDetector(
                              onTap: () {
                                context.read<CartProvider>().addItem(item);
                                _bounce();
                              },
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
                            ),
                          )
                        else
                          Row(
                            children: [
                              _qtyBtn(
                                Icons.remove,
                                () => context
                                    .read<CartProvider>()
                                    .removeItem(item.id),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5),
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                          scale: anim, child: child),
                                  child: Text(
                                    '$qty',
                                    key: ValueKey(qty),
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary),
                                  ),
                                ),
                              ),
                              _qtyBtn(
                                Icons.add,
                                () {
                                  context
                                      .read<CartProvider>()
                                      .addItem(item);
                                  _bounce();
                                },
                              ),
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
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      );

  Widget _imgPlaceholder() => Container(
        color: AppColors.primaryLight,
        child: const Center(
            child: Icon(Icons.shopping_basket_outlined,
                color: AppColors.primary, size: 40)),
      );
}

// ── Nearby stores list (mode 1) ───────────────────────────────────────────────

class _NearbyStoresList extends StatefulWidget {
  final CatalogProvider catalog;
  final ValueChanged<Map<String, dynamic>> onStoreTap;

  const _NearbyStoresList({
    required this.catalog,
    required this.onStoreTap,
  });

  @override
  State<_NearbyStoresList> createState() => _NearbyStoresListState();
}

class _NearbyStoresListState extends State<_NearbyStoresList> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.catalog.hasLocation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_searching_rounded,
                  size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text('Location not detected',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Go to the Home tab first to detect your location.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final stores = widget.catalog.allNearbyStores;
    final filtered = _query.isEmpty
        ? stores
        : stores.where((s) {
            final name = (s['name'] as String? ?? '').toLowerCase();
            final area = (s['area'] as String? ?? '').toLowerCase();
            return name.contains(_query.toLowerCase()) ||
                area.contains(_query.toLowerCase());
          }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 4,
                    offset: Offset(0, 1)),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search stores by name or area…',
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
        // List
        Expanded(
          child: stores.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.store_mall_directory_outlined,
                            size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text('No stores found nearby',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('DHAV is expanding — check back soon!',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No stores match "$_query"',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _StoreCard(
                        store: filtered[i],
                        onTap: () => widget.onStoreTap(filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Store card ────────────────────────────────────────────────────────────────

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = (store['is_active'] as bool? ?? false) &&
        !(store['is_suspended'] as bool? ?? false);
    final verified = store['is_verified'] as bool? ?? false;
    final name = store['name']?.toString() ?? 'Kirana Store';
    final area = store['area']?.toString() ?? '';
    final dist = (store['distance_km'] as num?)?.toDouble();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? AppColors.border
                  : AppColors.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 4,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryLight
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color:
                      isActive ? AppColors.primary : AppColors.textHint,
                  size: 26,
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
                            name,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.success
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('✓',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (area.isNotEmpty) ...[
                          Text(area,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const Text('  •  ',
                              style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 12)),
                        ],
                        if (dist != null)
                          Text('${dist.toStringAsFixed(1)} km',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.textHint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.success
                                : AppColors.textHint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textHint, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
