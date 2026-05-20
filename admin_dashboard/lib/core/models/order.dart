class AdminOrder {
  final String orderId;
  final String customerId;
  final String? acceptedByStoreId;
  final String status;
  final double totalAmount;
  final double platformFeeAmount;
  final int createdAt;
  final String deliveryAddress;
  final List<Map<String, dynamic>> items;

  AdminOrder({
    required this.orderId,
    required this.customerId,
    this.acceptedByStoreId,
    required this.status,
    required this.totalAmount,
    required this.platformFeeAmount,
    required this.createdAt,
    required this.deliveryAddress,
    required this.items,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> j) {
    final addr = j['delivery_address'] as Map<String, dynamic>? ?? {};
    final rawItems = j['items'] as List<dynamic>? ?? [];
    return AdminOrder(
      orderId: j['order_id'] ?? '',
      customerId: j['customer_id'] ?? '',
      acceptedByStoreId: j['accepted_by_store_id'],
      status: j['status'] ?? '',
      totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
      platformFeeAmount: (j['platform_fee_amount'] as num?)?.toDouble() ?? 0,
      createdAt: j['created_at'] ?? 0,
      deliveryAddress: addr['full_address'] ?? addr['area'] ?? 'N/A',
      items: rawItems.map((i) => Map<String, dynamic>.from(i as Map)).toList(),
    );
  }

  DateTime get createdDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt);
}
