class SavedAddress {
  final String label;
  final String flatBuilding;
  final String? floor;
  final String area;
  final String? landmark;
  final String city;
  final String? pincode;
  final double lat;
  final double lng;
  final int? createdAt;

  const SavedAddress({
    this.label = 'Home',
    required this.flatBuilding,
    this.floor,
    required this.area,
    this.landmark,
    this.city = 'Pune',
    this.pincode,
    required this.lat,
    required this.lng,
    this.createdAt,
  });

  String get displayTitle {
    if (flatBuilding.isNotEmpty) return '$flatBuilding, $area';
    return area;
  }

  String get fullAddress {
    final parts = <String>[
      if (flatBuilding.isNotEmpty) flatBuilding,
      if (floor != null && floor!.isNotEmpty) 'Floor $floor',
      area,
      city,
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toOrderAddress() => {
        'area': area,
        'city': city,
        'lat': lat,
        'lng': lng,
        'label': label,
        if (flatBuilding.isNotEmpty) 'flat_building': flatBuilding,
        if (floor != null && floor!.isNotEmpty) 'floor': floor,
        if (landmark != null && landmark!.isNotEmpty) 'landmark': landmark,
        if (pincode != null && pincode!.isNotEmpty) 'pincode': pincode,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        label: j['label'] as String? ?? 'Home',
        flatBuilding: j['flat_building'] as String? ?? '',
        floor: j['floor'] as String?,
        area: j['area'] as String? ?? '',
        landmark: j['landmark'] as String?,
        city: j['city'] as String? ?? 'Pune',
        pincode: j['pincode'] as String?,
        lat: (j['lat'] as num?)?.toDouble() ?? 18.5204,
        lng: (j['lng'] as num?)?.toDouble() ?? 73.8567,
        createdAt: j['created_at'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'flat_building': flatBuilding,
        'area': area,
        'city': city,
        'lat': lat,
        'lng': lng,
        if (floor != null && floor!.isNotEmpty) 'floor': floor,
        if (landmark != null && landmark!.isNotEmpty) 'landmark': landmark,
        if (pincode != null && pincode!.isNotEmpty) 'pincode': pincode,
      };

  SavedAddress copyWith({
    String? label,
    String? flatBuilding,
    String? floor,
    String? area,
    String? landmark,
    String? city,
    String? pincode,
    double? lat,
    double? lng,
  }) =>
      SavedAddress(
        label: label ?? this.label,
        flatBuilding: flatBuilding ?? this.flatBuilding,
        floor: floor ?? this.floor,
        area: area ?? this.area,
        landmark: landmark ?? this.landmark,
        city: city ?? this.city,
        pincode: pincode ?? this.pincode,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        createdAt: createdAt,
      );
}
