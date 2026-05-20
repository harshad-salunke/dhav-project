class AnalyticsSummary {
  final int totalStores;
  final int activeStores;
  final int totalOrders;
  final int deliveredOrders;
  final int failedOrders;
  final double successRatePct;
  final double platformFeeCollected;

  AnalyticsSummary({
    required this.totalStores,
    required this.activeStores,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.failedOrders,
    required this.successRatePct,
    required this.platformFeeCollected,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) {
    return AnalyticsSummary(
      totalStores: j['total_stores'] ?? 0,
      activeStores: j['active_stores'] ?? 0,
      totalOrders: j['total_orders'] ?? 0,
      deliveredOrders: j['delivered_orders'] ?? 0,
      failedOrders: j['failed_orders'] ?? 0,
      successRatePct: (j['success_rate_pct'] as num?)?.toDouble() ?? 0,
      platformFeeCollected: (j['platform_fee_collected'] as num?)?.toDouble() ?? 0,
    );
  }
}
