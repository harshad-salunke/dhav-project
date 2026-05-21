import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_client.dart';

class OrderProvider extends ChangeNotifier {
  List<CustomerOrder> _orders = [];
  CustomerOrder? _activeOrder;
  bool _loading = false;
  String? _error;

  List<CustomerOrder> get orders => _orders;
  CustomerOrder? get activeOrder => _activeOrder;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasActiveOrder => _activeOrder != null;

  Future<CustomerOrder?> placeOrder({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerAddress,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await ApiClient.post('/orders', {
        'customer_address': customerAddress,
        'items': items,
      });
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final order = CustomerOrder.fromJson(body);
        _activeOrder = order;
        notifyListeners();
        return order;
      } else {
        _error = 'Failed to place order: ${resp.body}';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CustomerOrder?> placeDirectOrder({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerAddress,
    required String storeId,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await ApiClient.post('/orders/direct', {
        'store_id': storeId,
        'customer_address': customerAddress,
        'items': items,
      });

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final order = CustomerOrder.fromJson(body);
        _activeOrder = order;
        notifyListeners();
        return order;
      } else {
        _error = 'Failed to place order: ${resp.body}';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CustomerOrder?> fetchOrder(String orderId) async {
    try {
      final resp = await ApiClient.get('/orders/$orderId');
      if (resp.statusCode == 200) {
        final order =
            CustomerOrder.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        if (_activeOrder?.orderId == orderId) {
          _activeOrder = order;
          notifyListeners();
        }
        return order;
      }
    } catch (e) {
      _error = e.toString();
    }
    return null;
  }

  Future<void> loadHistory() async {
    _loading = true;
    notifyListeners();
    try {
      final resp = await ApiClient.get('/orders/customer/me');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        _orders = data
            .map((e) => CustomerOrder.fromJson(e as Map<String, dynamic>))
            .toList();

        // Set active order if any in-progress
        _activeOrder = _orders.firstWhere(
          (o) => !['delivered', 'failed', 'cancelled'].contains(o.status),
          orElse: () => _orders.isNotEmpty ? _orders.first : CustomerOrder(
            orderId: '', customerId: '', status: 'none',
            items: [], deliveryAddress: '',
          ),
        );
        if (_activeOrder?.status == 'none') _activeOrder = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearActiveOrder() {
    _activeOrder = null;
    notifyListeners();
  }
}
