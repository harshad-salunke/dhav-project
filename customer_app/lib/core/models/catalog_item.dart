class CatalogItem {
  final String id;
  final String name;
  final String? nameHindi;
  final String? nameMarathi;
  final String category;
  final String unit;
  final String? imageUrl;
  final bool isAvailable;
  final double? price; // set by store after acceptance

  const CatalogItem({
    required this.id,
    required this.name,
    this.nameHindi,
    this.nameMarathi,
    required this.category,
    required this.unit,
    this.imageUrl,
    this.isAvailable = true,
    this.price,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        id: j['id'] ?? j['item_id'] ?? '',
        name: j['name'] ?? '',
        nameHindi: j['name_hindi'],
        nameMarathi: j['name_marathi'],
        category: j['category'] ?? '',
        unit: j['unit'] ?? '',
        imageUrl: j['image_url'],
        isAvailable: j['is_available'] ?? true,
        price: (j['price'] as num?)?.toDouble(),
      );
}

class CatalogCategory {
  final String id;
  final String name;
  final String? icon;

  const CatalogCategory({required this.id, required this.name, this.icon});

  factory CatalogCategory.fromJson(Map<String, dynamic> j) => CatalogCategory(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        icon: j['icon'],
      );
}
