import 'package:flutter/foundation.dart';

import '../models/store.dart';
import '../services/api_client.dart';

class StoreProvider extends ChangeNotifier {
  StoreProvider({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Store? _store;
  List<DeliveryBoy> _deliveryBoys = [];
  bool _loading = false;
  String? _error;

  Store? get store => _store;
  List<DeliveryBoy> get deliveryBoys => _deliveryBoys;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadMyStore() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.get('/stores/me') as Map<String, dynamic>;
      _store = Store.fromJson(res);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleOpen(bool open) async {
    if (_store == null) return;
    final previous = _store!.isOpen;
    _store = _store!.copyWith(isOpen: open);
    notifyListeners();
    try {
      await _api.patch('/stores/me/toggle', body: {'is_open': open});
    } catch (e) {
      _store = _store!.copyWith(isOpen: previous);
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadDeliveryBoys() async {
    if (_store == null) return;
    try {
      final res = await _api.get('/stores/me/delivery-boys') as Map<String, dynamic>;
      final list = (res['delivery_boys'] as List? ?? []);
      _deliveryBoys = list
          .map((e) => DeliveryBoy.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addDeliveryBoy({
    required String name,
    required String phone,
    required String googleAccountEmail,
  }) async {
    await _api.post('/stores/me/delivery-boys', body: {
      'name': name,
      'phone': phone,
      'google_account_email': googleAccountEmail,
    });
    await loadDeliveryBoys();
  }

  Future<void> removeDeliveryBoy(String deliveryBoyId) async {
    await _api.delete('/stores/me/delivery-boys/$deliveryBoyId');
    await loadDeliveryBoys();
  }

  Future<void> updateInventory(List<String> itemIds) async {
    if (_store == null) return;
    await _api.patch('/stores/me/inventory', body: {
      'available_item_ids': itemIds,
    });
    _store = _store!.copyWith(availableItemIds: itemIds);
    notifyListeners();
  }

  void reset() {
    _store = null;
    _deliveryBoys = [];
    _error = null;
    notifyListeners();
  }
}
