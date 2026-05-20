import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/analytics.dart';
import '../models/store.dart';
import '../models/order.dart';
import '../models/settlement.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  AnalyticsSummary? analytics;
  List<AdminStore> recentStores = [];
  List<AdminOrder> recentOrders = [];
  List<AdminSettlement> pendingSettlements = [];

  bool isLoading = false;
  String? error;

  Future<void> loadDashboard() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.get('/admin/analytics/summary'),
        _api.get('/admin/stores', query: {'limit': '5'}),
        _api.get('/admin/orders', query: {'limit': '10'}),
        _api.get('/admin/settlements', query: {'status': 'pending'}),
      ]);

      analytics = AnalyticsSummary.fromJson(results[0] as Map<String, dynamic>);

      final storesData = results[1] as Map<String, dynamic>;
      recentStores = (storesData['stores'] as List)
          .map((s) => AdminStore.fromJson(s as Map<String, dynamic>))
          .toList();

      final ordersData = results[2] as Map<String, dynamic>;
      recentOrders = (ordersData['orders'] as List)
          .map((o) => AdminOrder.fromJson(o as Map<String, dynamic>))
          .toList();

      final settlData = results[3] as Map<String, dynamic>;
      pendingSettlements = (settlData['settlements'] as List)
          .map((s) => AdminSettlement.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
