import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/order.dart';

class OrdersProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<AdminOrder> orders = [];
  AdminOrder? selectedOrder;
  bool isLoading = false;
  String? error;
  String? statusFilter;

  Future<void> loadOrders({String? status}) async {
    isLoading = true;
    error = null;
    statusFilter = status;
    notifyListeners();
    try {
      final query = <String, String>{'limit': '100'};
      if (status != null) query['status'] = status;
      final data = await _api.get('/admin/orders', query: query);
      orders = (data['orders'] as List)
          .map((o) => AdminOrder.fromJson(o as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> forceFailOrder(String orderId) async {
    try {
      await _api.post('/admin/orders/$orderId/force-fail');
      await loadOrders(status: statusFilter);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
