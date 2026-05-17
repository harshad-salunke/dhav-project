import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../services/api_client.dart';

class DeliveryProvider extends ChangeNotifier {
  DeliveryProvider({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  List<Order> _orders = [];
  bool _loading = false;
  String? _error;

  List<Order> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;

  Order? get activeAssignment =>
      _orders.cast<Order?>().firstWhere((o) => o!.isActive, orElse: () => null);

  Future<void> loadAssignments() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.get('/orders/delivery/me') as Map<String, dynamic>;
      _orders = (res['orders'] as List? ?? [])
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markDelivered(String orderId) async {
    await _api.post('/orders/$orderId/delivered');
    await loadAssignments();
  }
}
