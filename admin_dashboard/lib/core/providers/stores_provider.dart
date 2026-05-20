import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/store.dart';

class StoresProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<AdminStore> stores = [];
  AdminStore? selectedStore;
  bool isLoading = false;
  String? error;

  // Filters
  bool? filterActive;
  bool? filterSuspended;

  Future<void> loadStores() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final query = <String, String>{};
      if (filterActive != null) query['is_active'] = filterActive.toString();
      if (filterSuspended != null)
        query['is_suspended'] = filterSuspended.toString();

      final data = await _api.get('/admin/stores', query: query);
      stores = (data['stores'] as List)
          .map((s) => AdminStore.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStoreDetail(String storeId) async {
    isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get('/admin/stores/$storeId');
      selectedStore = AdminStore.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Creates store + Firebase Auth owner account. Returns the response map on
  /// success, null on failure (sets [error]).
  Future<Map<String, dynamic>?> onboardStore(
      Map<String, dynamic> payload) async {
    error = null;
    try {
      final result =
          await _api.post('/admin/stores/onboard', body: payload)
              as Map<String, dynamic>;
      await loadStores();
      return result;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateStore(
      String storeId, Map<String, dynamic> payload) async {
    error = null;
    try {
      await _api.put('/admin/stores/$storeId', body: payload);
      await loadStores();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStore(String storeId) async {
    error = null;
    try {
      await _api.delete('/admin/stores/$storeId');
      await loadStores();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyStore(String storeId) async {
    try {
      await _api.patch('/admin/stores/$storeId/verify');
      await loadStores();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> suspendStore(String storeId, int days) async {
    try {
      await _api.patch('/admin/stores/$storeId/suspend', body: {'days': days});
      await loadStores();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unsuspendStore(String storeId) async {
    try {
      await _api.patch('/admin/stores/$storeId/unsuspend');
      await loadStores();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void setFilter({bool? active, bool? suspended}) {
    filterActive = active;
    filterSuspended = suspended;
    loadStores();
  }
}
