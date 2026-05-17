class CatalogItem {
  final String itemId;
  final String name;
  final String? nameHindi;
  final String? nameMarathi;
  final String category;
  final String unit;
  final double price;
  final String? imageUrl;
  final bool isActive;

  const CatalogItem({
    required this.itemId,
    required this.name,
    this.nameHindi,
    this.nameMarathi,
    required this.category,
    required this.unit,
    required this.price,
    this.imageUrl,
    required this.isActive,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        itemId: j['item_id'] as String,
        name: j['name'] as String,
        nameHindi: j['name_hindi'] as String?,
        nameMarathi: j['name_marathi'] as String?,
        category: (j['category'] ?? '') as String,
        unit: (j['unit'] ?? '') as String,
        price: ((j['price'] ?? 0) as num).toDouble(),
        imageUrl: j['image_url'] as String?,
        isActive: (j['is_active'] ?? true) as bool,
      );
}
