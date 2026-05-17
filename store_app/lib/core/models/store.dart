class StoreLocation {
  final double lat;
  final double lng;
  final String? geohash;

  const StoreLocation({required this.lat, required this.lng, this.geohash});

  factory StoreLocation.fromJson(Map<String, dynamic> j) => StoreLocation(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        geohash: j['geohash'] as String?,
      );
}

class OperatingHours {
  final String open;
  final String close;
  const OperatingHours({required this.open, required this.close});

  factory OperatingHours.fromJson(Map<String, dynamic> j) =>
      OperatingHours(open: j['open'] as String, close: j['close'] as String);
}

class Store {
  final String storeId;
  final String ownerUid;
  final String ownerName;
  final String shopName;
  final String phone;
  final String email;
  final String? shopPhotoUrl;
  final String address;
  final StoreLocation location;
  final bool isOpen;
  final bool isActive;
  final bool isVerified;
  final bool isSuspended;
  final int? suspensionEndDate;
  final int strikeCount;
  final int totalStrikes;
  final List<String> availableItemIds;
  final OperatingHours? operatingHours;
  final int totalOrdersAccepted;
  final int totalOrdersFailed;
  final double rating;
  final String? fcmToken;

  const Store({
    required this.storeId,
    required this.ownerUid,
    required this.ownerName,
    required this.shopName,
    required this.phone,
    required this.email,
    this.shopPhotoUrl,
    required this.address,
    required this.location,
    required this.isOpen,
    required this.isActive,
    required this.isVerified,
    required this.isSuspended,
    this.suspensionEndDate,
    required this.strikeCount,
    required this.totalStrikes,
    required this.availableItemIds,
    this.operatingHours,
    required this.totalOrdersAccepted,
    required this.totalOrdersFailed,
    required this.rating,
    this.fcmToken,
  });

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        storeId: j['store_id'] as String,
        ownerUid: (j['owner_uid'] ?? '') as String,
        ownerName: (j['owner_name'] ?? '') as String,
        shopName: (j['shop_name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        shopPhotoUrl: j['shop_photo_url'] as String?,
        address: (j['address'] ?? '') as String,
        location: StoreLocation.fromJson(
          Map<String, dynamic>.from(j['location'] as Map),
        ),
        isOpen: (j['is_open'] ?? false) as bool,
        isActive: (j['is_active'] ?? true) as bool,
        isVerified: (j['is_verified'] ?? false) as bool,
        isSuspended: (j['is_suspended'] ?? false) as bool,
        suspensionEndDate: j['suspension_end_date'] as int?,
        strikeCount: (j['strike_count'] ?? 0) as int,
        totalStrikes: (j['total_strikes'] ?? 0) as int,
        availableItemIds: ((j['available_item_ids'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        operatingHours: j['operating_hours'] == null
            ? null
            : OperatingHours.fromJson(
                Map<String, dynamic>.from(j['operating_hours'] as Map)),
        totalOrdersAccepted: (j['total_orders_accepted'] ?? 0) as int,
        totalOrdersFailed: (j['total_orders_failed'] ?? 0) as int,
        rating: ((j['rating'] ?? 0) as num).toDouble(),
        fcmToken: j['fcm_token'] as String?,
      );

  Store copyWith({bool? isOpen, List<String>? availableItemIds}) => Store(
        storeId: storeId,
        ownerUid: ownerUid,
        ownerName: ownerName,
        shopName: shopName,
        phone: phone,
        email: email,
        shopPhotoUrl: shopPhotoUrl,
        address: address,
        location: location,
        isOpen: isOpen ?? this.isOpen,
        isActive: isActive,
        isVerified: isVerified,
        isSuspended: isSuspended,
        suspensionEndDate: suspensionEndDate,
        strikeCount: strikeCount,
        totalStrikes: totalStrikes,
        availableItemIds: availableItemIds ?? this.availableItemIds,
        operatingHours: operatingHours,
        totalOrdersAccepted: totalOrdersAccepted,
        totalOrdersFailed: totalOrdersFailed,
        rating: rating,
        fcmToken: fcmToken,
      );
}

class DeliveryBoy {
  final String deliveryBoyId;
  final String storeId;
  final String name;
  final String phone;
  final String? profilePhotoUrl;
  final String googleAccountEmail;
  final bool isActive;
  final String? currentOrderId;

  const DeliveryBoy({
    required this.deliveryBoyId,
    required this.storeId,
    required this.name,
    required this.phone,
    this.profilePhotoUrl,
    required this.googleAccountEmail,
    required this.isActive,
    this.currentOrderId,
  });

  factory DeliveryBoy.fromJson(Map<String, dynamic> j) => DeliveryBoy(
        deliveryBoyId: j['delivery_boy_id'] as String,
        storeId: (j['store_id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        profilePhotoUrl: j['profile_photo_url'] as String?,
        googleAccountEmail: (j['google_account_email'] ?? '') as String,
        isActive: (j['is_active'] ?? true) as bool,
        currentOrderId: j['current_order_id'] as String?,
      );
}
