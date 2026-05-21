import 'catalog_item.dart';

class CartItem {
  final CatalogItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});

  double get subtotal => (item.price ?? 0) * quantity;

  Map<String, dynamic> toOrderItem() => {
        'item_id': item.id,
        'item_name': item.name,
        'quantity': quantity,
        'unit': item.unit,
        'price_per_unit': item.price ?? 0.0,
        'total_price': subtotal,
        'is_catalog_item': true,
      };
}
