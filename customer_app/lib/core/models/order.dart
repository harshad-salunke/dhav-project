class OrderItem {
  final String itemId;
  final String name;
  final int quantity;
  final String unit;
  final double? price;

  const OrderItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        itemId: j['item_id'] ?? '',
        name: j['item_name'] as String? ?? j['name'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        unit: j['unit'] ?? '',
        price: (j['price_per_unit'] as num?)?.toDouble() ??
            (j['price'] as num?)?.toDouble(),
      );
}

class CustomerOrder {
  final String orderId;
  final String customerId;
  final String status;
  final List<OrderItem> items;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? productTotal;
  final double? deliveryFee;
  final double? platformFee;
  final String? storeId;
  final String? storeName;
  final String? storePhone;
  final String? deliveryBoyName;
  final String? deliveryBoyPhone;
  final String? wsChannelId;
  final DateTime? createdAt;
  final bool hasReview;

  const CustomerOrder({
    required this.orderId,
    required this.customerId,
    required this.status,
    required this.items,
    required this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.productTotal,
    this.deliveryFee,
    this.platformFee,
    this.storeId,
    this.storeName,
    this.storePhone,
    this.deliveryBoyName,
    this.deliveryBoyPhone,
    this.wsChannelId,
    this.createdAt,
    this.hasReview = false,
  });

  double get grandTotal => (productTotal ?? 0) + (deliveryFee ?? 0);

  static String _parseAddress(Map<String, dynamic> j) {
    final addr = j['customer_address'];
    if (addr is Map<String, dynamic>) {
      final parts = <String>[
        if ((addr['flat_building'] as String? ?? '').isNotEmpty)
          addr['flat_building'] as String,
        addr['area'] as String? ?? '',
        addr['city'] as String? ?? '',
      ];
      return parts.where((p) => p.isNotEmpty).join(', ');
    }
    return j['delivery_address'] as String? ?? '';
  }

  static double? _parseLat(Map<String, dynamic> j) {
    final addr = j['customer_address'];
    if (addr is Map<String, dynamic>) {
      return (addr['lat'] as num?)?.toDouble();
    }
    return (j['delivery_lat'] as num?)?.toDouble();
  }

  static double? _parseLng(Map<String, dynamic> j) {
    final addr = j['customer_address'];
    if (addr is Map<String, dynamic>) {
      return (addr['lng'] as num?)?.toDouble();
    }
    return (j['delivery_lng'] as num?)?.toDouble();
  }

  factory CustomerOrder.fromJson(Map<String, dynamic> j) => CustomerOrder(
        orderId: j['order_id'] ?? '',
        customerId: j['customer_id'] ?? '',
        status: j['status'] ?? 'pending',
        items: (j['items'] as List? ?? [])
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        deliveryAddress: CustomerOrder._parseAddress(j),
        deliveryLat: CustomerOrder._parseLat(j),
        deliveryLng: CustomerOrder._parseLng(j),
        productTotal: (j['product_total'] as num?)?.toDouble(),
        deliveryFee: (j['delivery_fee'] as num?)?.toDouble(),
        platformFee: (j['platform_fee_amount'] as num?)?.toDouble(),
        storeId: j['store_id'],
        storeName: j['store_name'],
        storePhone: j['store_phone'],
        deliveryBoyName: j['delivery_boy_name'],
        deliveryBoyPhone: j['delivery_boy_phone'],
        wsChannelId: j['ws_channel_id'],
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
        hasReview: j['has_review'] == true,
      );
}
