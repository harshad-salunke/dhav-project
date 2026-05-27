// lib/core/widgets/shimmer_widgets.dart
// Reusable shimmer loading skeletons for the DHAV Store App.
// Every skeleton mirrors the exact layout of the real content it replaces,
// so the transition from loading → content is smooth and non-jarring.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/dhav_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BASE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// The base shimmer wrapper. Wrap any skeleton widget with this.
/// Automatically adjusts base/highlight colours for dark vs light theme.
class DhavShimmer extends StatelessWidget {
  final Widget child;
  const DhavShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark
          ? const Color(0xFF2A2F3E)
          : const Color(0xFFE8E8E8),
      highlightColor: isDark
          ? const Color(0xFF3D4560)
          : const Color(0xFFF5F5F5),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circular shimmer placeholder (for avatars, icons).
class ShimmerCircle extends StatelessWidget {
  final double size;
  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFE8E8E8),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the entire dashboard home tab while store + orders are loading.
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store status card skeleton
            _StoreStatusCardSkeleton(),
            const SizedBox(height: 16),
            // Stats row skeleton
            _StatsRowSkeleton(),
            const SizedBox(height: 20),
            // Section label
            const ShimmerBox(width: 140, height: 12, radius: 4),
            const SizedBox(height: 12),
            // Active order card
            _ActiveOrderCardSkeleton(),
            const SizedBox(height: 20),
            // Recent orders label
            Row(
              children: [
                const ShimmerBox(width: 120, height: 14, radius: 4),
                const Spacer(),
                const ShimmerBox(width: 60, height: 12, radius: 4),
              ],
            ),
            const SizedBox(height: 12),
            _OrderRowSkeleton(),
            const SizedBox(height: 2),
            _OrderRowSkeleton(),
            const SizedBox(height: 2),
            _OrderRowSkeleton(),
          ],
        ),
      ),
    );
  }
}

class _StoreStatusCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 160, height: 10, radius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: 80, height: 28, radius: 6),
              ],
            ),
          ),
          const ShimmerBox(width: 46, height: 28, radius: 14),
        ],
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: Column(
              children: const [
                ShimmerBox(width: 60, height: 10, radius: 4),
                SizedBox(height: 4),
                ShimmerBox(width: 48, height: 28, radius: 6),
              ],
            ),
          ),
          if (i < 2) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _ActiveOrderCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              ShimmerBox(width: 160, height: 20, radius: 6),
              Spacer(),
              ShimmerBox(width: 80, height: 14, radius: 4),
            ],
          ),
          const SizedBox(height: 8),
          const ShimmerBox(width: 120, height: 12, radius: 4),
          const SizedBox(height: 14),
          const ShimmerBox.fill(height: 44, radius: 10),
        ],
      ),
    );
  }
}

class _OrderRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const ShimmerBox(width: 40, height: 40, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 140, height: 12, radius: 4),
                SizedBox(height: 4),
                ShimmerBox(width: 90, height: 10, radius: 4),
              ],
            ),
          ),
          const ShimmerBox(width: 50, height: 14, radius: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVENTORY SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the inventory list (replaces CircularProgressIndicator).
class InventoryShimmer extends StatelessWidget {
  const InventoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _InventoryItemSkeleton(),
      ),
    );
  }
}

class _InventoryItemSkeleton extends StatelessWidget {
  const _InventoryItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 52, height: 52, radius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 140, height: 13, radius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 90, height: 10, radius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 50, height: 12, radius: 4),
              ],
            ),
          ),
          const ShimmerBox(width: 46, height: 28, radius: 14),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER LIST SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the orders list tab.
class OrderListShimmer extends StatelessWidget {
  const OrderListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              ShimmerBox(width: 150, height: 16, radius: 5),
              Spacer(),
              ShimmerBox(width: 80, height: 22, radius: 6),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              ShimmerBox(width: 70, height: 12, radius: 4),
              SizedBox(width: 16),
              ShimmerBox(width: 50, height: 12, radius: 4),
              Spacer(),
              ShimmerBox(width: 55, height: 16, radius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER DETAIL SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the order detail screen.
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
            // Order header
            const ShimmerBox.fill(height: 80, radius: 14),
            const SizedBox(height: 16),
            // Status badge
            const ShimmerBox(width: 120, height: 28, radius: 8),
            const SizedBox(height: 20),
            // Section label
            const ShimmerBox(width: 80, height: 11, radius: 4),
            const SizedBox(height: 10),
            // Items
            for (int i = 0; i < 3; i++) ...[
              _ItemRowSkeleton(),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            // Price breakdown
            const ShimmerBox.fill(height: 130, radius: 14),
            const SizedBox(height: 16),
            // Address
            const ShimmerBox.fill(height: 80, radius: 14),
          ],
        ),
      ),
    );
  }
}

class _ItemRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        ShimmerBox(width: 36, height: 36, radius: 8),
        SizedBox(width: 12),
        Expanded(child: ShimmerBox.fill(height: 12, radius: 4)),
        SizedBox(width: 12),
        ShimmerBox(width: 60, height: 12, radius: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EARNINGS SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the earnings screen (dark background).
class EarningsShimmer extends StatelessWidget {
  const EarningsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    // Always dark-theme shimmer for earnings
    return Shimmer.fromColors(
      baseColor: const Color(0xFF252A3A),
      highlightColor: const Color(0xFF3A4060),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current week card
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 14),
            // UPI card
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 22),
            // History label
            Container(
              width: 140,
              height: 11,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < 4; i++) ...[
              Container(
                width: double.infinity,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY HOME SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the delivery home screen.
class DeliveryHomeShimmer extends StatelessWidget {
  const DeliveryHomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            const ShimmerBox.fill(height: 110, radius: 16),
            const SizedBox(height: 16),
            // Stats
            Row(
              children: const [
                Expanded(child: ShimmerBox.fill(height: 80, radius: 14)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox.fill(height: 80, radius: 14)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox.fill(height: 80, radius: 14)),
              ],
            ),
            const SizedBox(height: 20),
            // Section label
            const ShimmerBox(width: 120, height: 12, radius: 4),
            const SizedBox(height: 12),
            for (int i = 0; i < 4; i++) ...[
              _OrderRowSkeleton(),
              const SizedBox(height: 2),
            ],
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
        itemCount: 6,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
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
          const ShimmerCircle(size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox.fill(height: 13, radius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 200, height: 11, radius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 80, height: 10, radius: 4),
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
// TEAM / DELIVERY BOY LIST SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the store team (delivery boys) list.
class TeamListShimmer extends StatelessWidget {
  const TeamListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _TeamMemberSkeleton(),
      ),
    );
  }
}

class _TeamMemberSkeleton extends StatelessWidget {
  const _TeamMemberSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const ShimmerCircle(size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 130, height: 13, radius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 90, height: 11, radius: 4),
              ],
            ),
          ),
          const ShimmerBox(width: 28, height: 28, radius: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for the store profile screen header.
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DhavShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + name
            const ShimmerCircle(size: 72),
            const SizedBox(height: 12),
            const ShimmerBox(width: 150, height: 16, radius: 6),
            const SizedBox(height: 6),
            const ShimmerBox(width: 100, height: 12, radius: 4),
            const SizedBox(height: 24),
            // Info cards
            for (int i = 0; i < 4; i++) ...[
              const ShimmerBox.fill(height: 52, radius: 12),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
