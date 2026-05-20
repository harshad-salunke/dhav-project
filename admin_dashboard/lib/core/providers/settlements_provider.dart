import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/settlement.dart';

class SettlementsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<AdminSettlement> settlements = [];
  bool isLoading = false;
  String? error;
  String? statusFilter;

  Future<void> loadSettlements({String? status}) async {
    isLoading = true;
    error = null;
    statusFilter = status;
    notifyListeners();
    try {
      final query = <String, String>{};
      if (status != null) query['status'] = status;
      final data = await _api.get('/admin/settlements', query: query);
      settlements = (data['settlements'] as List)
          .map((s) => AdminSettlement.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markPaid(String settlementId) async {
    try {
      await _api.post('/settlements/$settlementId/mark-paid');
      await loadSettlements(status: statusFilter);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
