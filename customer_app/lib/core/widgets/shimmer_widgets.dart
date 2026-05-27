// lib/core/widgets/shimmer_widgets.dart
// Reusable shimmer loading skeletons for the DHAV Customer App.
// Every skeleton mirrors the real content layout for a smooth loading experience.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BASE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// The base shimmer wrapper — always light-theme consistent with customer app.
class DhavShimmer extends StatelessWidget {
  final Widget child;
  const DhavShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEAEAEA),
      highlightColor: const Color(0xFFF8F8F8),
      child: child,
    );
  }
}

/// A plain rectangular shimmer placeholder.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  const ShimmerBox.fill({
    super.key,
    required this.height,
    this.radius = 8,
  }) : width = double.infinity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circular shimmer placeholder.
class ShimmerCircle extends StatelessWidget {
  final double size;
  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEAEAEA),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Full skeleton for the Home screen while catalog data is loading.
/// Mirrors: search bar, category chips, "Order Again" row, 2-col product grid.
class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Search bar skeleton
            const ShimmerBox.fill(height: 48, radius: 12),
            const SizedBox(height: 16),
            // Hero banner
            const ShimmerBox.fill(height: 120, radius: 14),
            const SizedBox(height: 16),
            // Category chips row
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ShimmerBox(
                  width: 70.0 + (i % 2 == 0 ? 10 : 0),
                  height: 36,
                  radius: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Section label
            const ShimmerBox(width: 120, height: 14, radius: 4),
            const SizedBox(height: 12),
            // "Order Again" horizontal scroll
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const ShimmerBox(
                    width: 90, height: 100, radius: 12),
              ),
            ),
            const SizedBox(height: 20),
            // "Fresh For You" label
            const ShimmerBox(width: 110, height: 14, radius: 4),
            const SizedBox(height: 12),
            // 2-col product grid (3 rows)
            for (int row = 0; row < 3; row++) ...[
              Row(
                children: const [
                  Expanded(child: _ProductCardSkeleton()),
                  SizedBox(width: 12),
                  Expanded(child: _ProductCardSkeleton()),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        ShimmerBox.fill(height: 110, radius: 12),
        SizedBox(height: 8),
        ShimmerBox(width: 100, height: 12, radius: 4),
        SizedBox(height: 4),
        ShimmerBox(width: 60, height: 11, radius: 4),
        SizedBox(height: 6),
        ShimmerBox.fill(height: 32, radius: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER HISTORY SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the order history list (Active + Past tabs).
class OrderHistoryShimmer extends StatelessWidget {
  const OrderHistoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _OrderCardSkeleton(),
      ),
    );
  }
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              ShimmerBox(width: 130, height: 15, radius: 5),
              Spacer(),
              ShimmerBox(width: 75, height: 22, radius: 6),
            ],
          ),
          const SizedBox(height: 8),
          const ShimmerBox(width: 180, height: 11, radius: 4),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: ShimmerBox.fill(height: 36, radius: 8)),
              SizedBox(width: 10),
              Expanded(child: ShimmerBox.fill(height: 36, radius: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH SCREEN SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the search results list.
class SearchResultsShimmer extends StatelessWidget {
  const SearchResultsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const _SearchItemSkeleton(),
      ),
    );
  }
}

class _SearchItemSkeleton extends StatelessWidget {
  const _SearchItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 60, height: 60, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 130, height: 13, radius: 4),
                SizedBox(height: 5),
                ShimmerBox(width: 80, height: 11, radius: 4),
                SizedBox(height: 5),
                ShimmerBox(width: 55, height: 13, radius: 4),
              ],
            ),
          ),
          const ShimmerBox(width: 72, height: 34, radius: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STORE DETAIL SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the store detail screen.
class StoreDetailShimmer extends StatelessWidget {
  const StoreDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store header banner
            const ShimmerBox.fill(height: 160, radius: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store name + rating
                  Row(
                    children: const [
                      Expanded(child: ShimmerBox.fill(height: 20, radius: 6)),
                      SizedBox(width: 16),
                      ShimmerBox(width: 60, height: 28, radius: 8),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const ShimmerBox(width: 180, height: 12, radius: 4),
                  const SizedBox(height: 20),
                  // Category chips
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) =>
                          ShimmerBox(width: 80.0, height: 34, radius: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Product grid
                  for (int row = 0; row < 4; row++) ...[
                    Row(
                      children: const [
                        Expanded(child: _ProductCardSkeleton()),
                        SizedBox(width: 12),
                        Expanded(child: _ProductCardSkeleton()),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the notifications screen.
class NotificationsShimmer extends StatelessWidget {
  const NotificationsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 7,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, thickness: 0.5),
        itemBuilder: (_, __) => const _NotificationTileSkeleton(),
      ),
    );
  }
}

class _NotificationTileSkeleton extends StatelessWidget {
  const _NotificationTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerCircle(size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox.fill(height: 13, radius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 220, height: 11, radius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 70, height: 10, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const ShimmerBox(width: 8, height: 8, radius: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART / ITEM DETAIL SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the cart screen while address / items are loading.
class CartShimmer extends StatelessWidget {
  const CartShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Address section
            const ShimmerBox.fill(height: 72, radius: 12),
            const SizedBox(height: 20),
            // Items section label
            const ShimmerBox(width: 100, height: 13, radius: 4),
            const SizedBox(height: 12),
            for (int i = 0; i < 4; i++) ...[
              _CartItemSkeleton(),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            // Price breakdown
            const ShimmerBox.fill(height: 140, radius: 14),
            const SizedBox(height: 16),
            // Place order button
            const ShimmerBox.fill(height: 52, radius: 12),
          ],
        ),
      ),
    );
  }
}

class _CartItemSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ShimmerBox(width: 56, height: 56, radius: 10),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerBox(width: 130, height: 13, radius: 4),
              SizedBox(height: 5),
              ShimmerBox(width: 80, height: 11, radius: 4),
            ],
          ),
        ),
        const ShimmerBox(width: 100, height: 32, radius: 8),
      ],
    );
  }
}

/// Skeleton for item detail screen.
class ItemDetailShimmer extends StatelessWidget {
  const ItemDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox.fill(height: 240, radius: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 200, height: 20, radius: 6),
                  SizedBox(height: 8),
                  ShimmerBox(width: 100, height: 14, radius: 4),
                  SizedBox(height: 16),
                  ShimmerBox.fill(height: 60, radius: 10),
                  SizedBox(height: 20),
                  ShimmerBox.fill(height: 52, radius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER DETAIL SHIMMER (customer)
// ─────────────────────────────────────────────────────────────────────────────

class OrderDetailShimmer extends StatelessWidget {
  const OrderDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox.fill(height: 100, radius: 14),
            const SizedBox(height: 16),
            const ShimmerBox(width: 110, height: 26, radius: 8),
            const SizedBox(height: 20),
            const ShimmerBox(width: 80, height: 12, radius: 4),
            const SizedBox(height: 10),
            for (int i = 0; i < 3; i++) ...[
              Row(
                children: const [
                  ShimmerBox(width: 36, height: 36, radius: 8),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerBox.fill(height: 12, radius: 4)),
                  SizedBox(width: 12),
                  ShimmerBox(width: 60, height: 12, radius: 4),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            const ShimmerBox.fill(height: 130, radius: 14),
            const SizedBox(height: 16),
            const ShimmerBox.fill(height: 80, radius: 14),
          ],
        ),
      ),
    );
  }
}
