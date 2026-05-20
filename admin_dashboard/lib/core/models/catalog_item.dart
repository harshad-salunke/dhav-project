class AdminCatalogItem {
  final String itemId;
  final String name;
  final String nameHindi;
  final String nameMarathi;
  final String category;
  final String unit;
  final String imageUrl;
  final bool isActive;
  final int? createdAt;

  AdminCatalogItem({
    required this.itemId,
    required this.name,
    required this.nameHindi,
    required this.nameMarathi,
    required this.category,
    required this.unit,
    required this.imageUrl,
    required this.isActive,
    this.createdAt,
  });

  factory AdminCatalogItem.fromJson(Map<String, dynamic> j) {
    return AdminCatalogItem(
      itemId: j['item_id'] ?? '',
      name: j['name'] ?? '',
      nameHindi: j['name_hindi'] ?? '',
      nameMarathi: j['name_marathi'] ?? '',
      category: j['category'] ?? '',
      unit: j['unit'] ?? '',
      imageUrl: j['image_url'] ?? '',
      isActive: j['is_active'] ?? true,
      createdAt: j['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'name_hindi': nameHindi,
        'name_marathi': nameMarathi,
        'category': category,
        'unit': unit,
        'image_url': imageUrl,
      };
}

class StoreInventoryItem {
  final String itemId;
  final String name;
  final String category;
  final String unit;
  bool isAvailable;
  int quantity;

  StoreInventoryItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.unit,
    required this.isAvailable,
    required this.quantity,
  });

  factory StoreInventoryItem.fromJson(Map<String, dynamic> j) {
    return StoreInventoryItem(
      itemId: j['item_id'] ?? '',
      name: j['name'] ?? '',
      category: j['category'] ?? '',
      unit: j['unit'] ?? '',
      isAvailable: j['is_available'] ?? false,
      quantity: j['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toPayload() => {
        'item_id': itemId,
        'is_available': isAvailable,
        'quantity': quantity,
      };
}

class StoreReview {
  final String reviewId;
  final String customerName;
  final double rating;
  final String comment;
  final int createdAt;

  StoreReview({
    required this.reviewId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory StoreReview.fromJson(Map<String, dynamic> j) {
    return StoreReview(
      reviewId: j['review_id'] ?? '',
      customerName: j['customer_name'] ?? 'Anonymous',
      rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
      comment: j['comment'] ?? '',
      createdAt: j['created_at'] ?? 0,
    );
  }
}

class StoreStats {
  final String storeId;
  final String storeName;
  final int totalOrders;
  final int deliveredOrders;
  final int failedOrders;
  final int pendingOrders;
  final double successRatePct;
  final double totalRevenue;
  final double platformFeeCollected;
  final List<Map<String, dynamic>> recentOrders;

  StoreStats({
    required this.storeId,
    required this.storeName,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.failedOrders,
    required this.pendingOrders,
    required this.successRatePct,
    required this.totalRevenue,
    required this.platformFeeCollected,
    required this.recentOrders,
  });

  factory StoreStats.fromJson(Map<String, dynamic> j) {
    return StoreStats(
      storeId: j['store_id'] ?? '',
      storeName: j['store_name'] ?? '',
      totalOrders: j['total_orders'] ?? 0,
      deliveredOrders: j['delivered_orders'] ?? 0,
      failedOrders: j['failed_orders'] ?? 0,
      pendingOrders: j['pending_orders'] ?? 0,
      successRatePct: (j['success_rate_pct'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (j['total_revenue'] as num?)?.toDouble() ?? 0.0,
      platformFeeCollected:
          (j['platform_fee_collected'] as num?)?.toDouble() ?? 0.0,
      recentOrders: (j['recent_orders'] as List?)
              ?.map((o) => o as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}
