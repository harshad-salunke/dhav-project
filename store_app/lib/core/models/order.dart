class OrderAddress {
  final String? addressId;
  final String label;
  final String? flatBuilding;
  final String? street;
  final String area;
  final String city;
  final String? pincode;
  final double lat;
  final double lng;

  const OrderAddress({
    this.addressId,
    required this.label,
    this.flatBuilding,
    this.street,
    required this.area,
    required this.city,
    this.pincode,
    required this.lat,
    required this.lng,
  });

  factory OrderAddress.fromJson(Map<String, dynamic> j) => OrderAddress(
        addressId: j['address_id'] as String?,
        label: (j['label'] ?? 'Home') as String,
        flatBuilding: j['flat_building'] as String?,
        street: j['street'] as String?,
        area: (j['area'] ?? '') as String,
        city: (j['city'] ?? 'Pune') as String,
        pincode: j['pincode'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );

  String get oneLine {
    final parts = <String>[];
    if (flatBuilding?.isNotEmpty == true) parts.add(flatBuilding!);
    if (street?.isNotEmpty == true) parts.add(street!);
    parts.add(area);
    return parts.join(', ');
  }
}

class OrderItem {
  final String itemId;
  final String itemName;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalPrice;
  final bool isCatalogItem;

  const OrderItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalPrice,
    required this.isCatalogItem,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        itemId: j['item_id'] as String,
        itemName: (j['item_name'] ?? '') as String,
        quantity: (j['quantity'] as num).toDouble(),
        unit: (j['unit'] ?? '') as String,
        pricePerUnit: ((j['price_per_unit'] ?? 0) as num).toDouble(),
        totalPrice: ((j['total_price'] ?? 0) as num).toDouble(),
        isCatalogItem: (j['is_catalog_item'] ?? true) as bool,
      );
}

class Order {
  final String orderId;
  final String customerId;
  final OrderAddress customerAddress;
  final List<OrderItem> items;
  final double totalProductAmount;
  final double deliveryFee;
  final double totalCustomerAmount;
  final double platformFeeAmount;
  final String paymentMethod;
  final String status;
  final int broadcastWave;
  final double broadcastRadiusKm;
  final String? acceptedByStoreId;
  final int? acceptedAt;
  final String? assignedDeliveryBoyId;
  final String? deliveryBoyName;
  final String? deliveryBoyPhone;
  final String? wsChannelId;
  final int estimatedDeliveryMinutes;
  final int? deliveredAt;
  final String? failureReason;
  final int? createdAt;

  const Order({
    required this.orderId,
    required this.customerId,
    required this.customerAddress,
    required this.items,
    required this.totalProductAmount,
    required this.deliveryFee,
    required this.totalCustomerAmount,
    required this.platformFeeAmount,
    required this.paymentMethod,
    required this.status,
    required this.broadcastWave,
    required this.broadcastRadiusKm,
    this.acceptedByStoreId,
    this.acceptedAt,
    this.assignedDeliveryBoyId,
    this.deliveryBoyName,
    this.deliveryBoyPhone,
    this.wsChannelId,
    required this.estimatedDeliveryMinutes,
    this.deliveredAt,
    this.failureReason,
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        orderId: j['order_id'] as String,
        customerId: j['customer_id'] as String,
        customerAddress: OrderAddress.fromJson(
            Map<String, dynamic>.from(j['customer_address'] as Map)),
        items: ((j['items'] as List?) ?? const [])
            .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        totalProductAmount: ((j['total_product_amount'] ?? 0) as num).toDouble(),
        deliveryFee: ((j['delivery_fee'] ?? 0) as num).toDouble(),
        totalCustomerAmount: ((j['total_customer_amount'] ?? 0) as num).toDouble(),
        platformFeeAmount: ((j['platform_fee_amount'] ?? 0) as num).toDouble(),
        paymentMethod: (j['payment_method'] ?? 'cod') as String,
        status: (j['status'] ?? 'pending') as String,
        broadcastWave: (j['broadcast_wave'] ?? 0) as int,
        broadcastRadiusKm: ((j['broadcast_radius_km'] ?? 0) as num).toDouble(),
        acceptedByStoreId: j['accepted_by_store_id'] as String?,
        acceptedAt: j['accepted_at'] as int?,
        assignedDeliveryBoyId: j['assigned_delivery_boy_id'] as String?,
        deliveryBoyName: j['delivery_boy_name'] as String?,
        deliveryBoyPhone: j['delivery_boy_phone'] as String?,
        wsChannelId: j['ws_channel_id'] as String?,
        estimatedDeliveryMinutes: (j['estimated_delivery_minutes'] ?? 30) as int,
        deliveredAt: j['delivered_at'] as int?,
        failureReason: j['failure_reason'] as String?,
        createdAt: j['created_at'] as int?,
      );

  bool get isActive =>
      const ['accepted', 'packed', 'out_for_delivery'].contains(status);
  bool get isTerminal =>
      const ['delivered', 'failed', 'cancelled'].contains(status);
  int get itemCount => items.length;
}
