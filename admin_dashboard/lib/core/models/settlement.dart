class AdminSettlement {
  final String settlementId;
  final String storeId;
  final String storeName;
  final String weekStart;
  final String weekEnd;
  final int deliveredOrderCount;
  final double totalFeeOwed;
  final String status;
  final bool isOverdue;
  final int createdAt;

  AdminSettlement({
    required this.settlementId,
    required this.storeId,
    required this.storeName,
    required this.weekStart,
    required this.weekEnd,
    required this.deliveredOrderCount,
    required this.totalFeeOwed,
    required this.status,
    required this.isOverdue,
    required this.createdAt,
  });

  factory AdminSettlement.fromJson(Map<String, dynamic> j) {
    return AdminSettlement(
      settlementId: j['settlement_id'] ?? '',
      storeId: j['store_id'] ?? '',
      storeName: j['store_name'] ?? '',
      weekStart: j['week_start'] ?? '',
      weekEnd: j['week_end'] ?? '',
      deliveredOrderCount: j['delivered_order_count'] ?? 0,
      totalFeeOwed: (j['total_fee_owed'] as num?)?.toDouble() ?? 0,
      status: j['status'] ?? 'pending',
      isOverdue: j['is_overdue'] ?? false,
      createdAt: j['created_at'] ?? 0,
    );
  }
}
