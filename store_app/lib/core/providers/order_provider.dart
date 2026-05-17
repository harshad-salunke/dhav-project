import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../services/api_client.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  List<Order> _orders = [];
  Order? _selected;
  bool _loading = false;
  String? _error;

  List<Order> get orders => _orders;
  Order? get selected => _selected;
  bool get loading => _loading;
  String? get error => _error;

  Order? get activeOrder =>
      _orders.cast<Order?>().firstWhere((o) => o!.isActive, orElse: () => null);

  List<Order> get recent => _orders
      .where((o) => o.isTerminal)
      .toList(growable: false);

  Future<void> loadStoreOrders() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.get('/stores/me/orders') as Map<String, dynamic>;
      final list = (res['orders'] as List? ?? []);
      _orders = list
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Order> loadOrder(String orderId) async {
    final res = await _api.get('/orders/$orderId') as Map<String, dynamic>;
    final order = Order.fromJson(res);
    _selected = order;
    notifyListeners();
    return order;
  }

  Future<void> accept(String orderId) async {
    await _api.post('/orders/$orderId/accept');
    await loadStoreOrders();
  }

  Future<void> reject(String orderId, {String? reason}) async {
    await _api.post('/orders/$orderId/reject', body: {'reason': reason});
  }

  Future<void> assignDeliveryBoy(String orderId, String deliveryBoyId) async {
    await _api.post('/orders/$orderId/assign-delivery-boy',
        body: {'delivery_boy_id': deliveryBoyId});
    await loadOrder(orderId);
  }

  Future<void> markPacked(String orderId) async {
    await _api.post('/orders/$orderId/packed');
    await loadOrder(orderId);
  }

  Future<void> markDispatched(String orderId) async {
    await _api.post('/orders/$orderId/dispatched');
    await loadOrder(orderId);
  }

  Future<void> markDelivered(String orderId) async {
    await _api.post('/orders/$orderId/delivered');
    await loadOrder(orderId);
  }

  Future<void> reportFailure(String orderId) async {
    await _api.post('/orders/$orderId/report-failure');
    await loadOrder(orderId);
  }

  void clearSelected() {
    _selected = null;
    notifyListeners();
  }

  void reset() {
    _orders = [];
    _selected = null;
    _error = null;
    notifyListeners();
  }
}
