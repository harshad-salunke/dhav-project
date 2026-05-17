import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/catalog_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String _deliveryAddress = '';
  double? _deliveryLat;
  double? _deliveryLng;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => _items.isEmpty;

  String get deliveryAddress => _deliveryAddress;
  double? get deliveryLat => _deliveryLat;
  double? get deliveryLng => _deliveryLng;

  double get subtotal => _items.fold(0, (sum, i) => sum + i.subtotal);

  void addItem(CatalogItem item) {
    final idx = _items.indexWhere((c) => c.item.id == item.id);
    if (idx >= 0) {
      _items[idx].quantity++;
    } else {
      _items.add(CartItem(item: item));
    }
    notifyListeners();
  }

  void removeItem(String itemId) {
    final idx = _items.indexWhere((c) => c.item.id == itemId);
    if (idx < 0) return;
    if (_items[idx].quantity > 1) {
      _items[idx].quantity--;
    } else {
      _items.removeAt(idx);
    }
    notifyListeners();
  }

  void deleteItem(String itemId) {
    _items.removeWhere((c) => c.item.id == itemId);
    notifyListeners();
  }

  int quantityOf(String itemId) {
    final idx = _items.indexWhere((c) => c.item.id == itemId);
    return idx >= 0 ? _items[idx].quantity : 0;
  }

  void setDeliveryAddress(String address, {double? lat, double? lng}) {
    _deliveryAddress = address;
    _deliveryLat = lat;
    _deliveryLng = lng;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toOrderItems() =>
      _items.map((c) => c.toOrderItem()).toList();
}
