/// Returns the first value in [candidates] that is a non-empty string,
/// or '' if none qualify. Used to bridge differing field names between the
/// old Firebase API and the Postgres schema (e.g. `id` vs `store_id`).
String _firstNonEmpty(List<dynamic> candidates) {
  for (final c in candidates) {
    if (c is String && c.isNotEmpty) return c;
  }
  return '';
}

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
    // Postgres `stores` primary key is `id`; the old Firebase API used
    // `store_id`. Accept both so verify/suspend/detail URLs are never blank.
    final id = _firstNonEmpty([j['id'], j['store_id']]);
    // Admin-onboarded stores use `name`; self-registered stores use
    // `shop_name`. Self-registered stores have no `area`, so fall back to
    // address.
    return AdminStore(
      storeId: id,
      name: _firstNonEmpty([j['name'], j['shop_name']]),
      ownerName: j['owner_name'] ?? '',
      phone: j['phone'] ?? '',
      area: _firstNonEmpty([j['area'], j['address']]),
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
