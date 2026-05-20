class AdminStore {
  final String storeId;
  final String name;
  final String ownerName;
  final String phone;
  final String area;
  final bool isActive;
  final bool isVerified;
  final bool isSuspended;
  final int strikeCount;
  final int? suspensionEndDate;
  final double? lat;
  final double? lng;

  AdminStore({
    required this.storeId,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.area,
    required this.isActive,
    required this.isVerified,
    required this.isSuspended,
    required this.strikeCount,
    this.suspensionEndDate,
    this.lat,
    this.lng,
  });

  factory AdminStore.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] as Map<String, dynamic>? ?? {};
    return AdminStore(
      storeId: j['store_id'] ?? '',
      name: j['name'] ?? '',
      ownerName: j['owner_name'] ?? '',
      phone: j['phone'] ?? '',
      area: j['area'] ?? '',
      isActive: j['is_active'] ?? false,
      isVerified: j['is_verified'] ?? false,
      isSuspended: j['is_suspended'] ?? false,
      strikeCount: j['strike_count'] ?? 0,
      suspensionEndDate: j['suspension_end_date'],
      lat: (loc['lat'] as num?)?.toDouble(),
      lng: (loc['lng'] as num?)?.toDouble(),
    );
  }

  String get statusLabel {
    if (isSuspended) return 'Suspended';
    if (!isVerified) return 'Unverified';
    if (isActive) return 'Online';
    return 'Offline';
  }
}
