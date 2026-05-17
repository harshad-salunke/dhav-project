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
        name: j['name'] ?? '',
        quantity: j['quantity'] ?? 1,
        unit: j['unit'] ?? '',
        price: (j['price'] as num?)?.toDouble(),
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
  });

  double get grandTotal => (productTotal ?? 0) + (deliveryFee ?? 0);

  factory CustomerOrder.fromJson(Map<String, dynamic> j) => CustomerOrder(
        orderId: j['order_id'] ?? '',
        customerId: j['customer_id'] ?? '',
        status: j['status'] ?? 'pending',
        items: (j['items'] as List? ?? [])
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        deliveryAddress: j['delivery_address'] ?? '',
        deliveryLat: (j['delivery_lat'] as num?)?.toDouble(),
        deliveryLng: (j['delivery_lng'] as num?)?.toDouble(),
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
      );
}
