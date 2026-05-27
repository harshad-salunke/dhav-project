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

  Future<void> updateProfile({
    String? shopName,
    String? ownerName,
    String? phone,
    String? address,
    double? lat,
    double? lng,
    String? openTime,
    String? closeTime,
  }) async {
    if (_store == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{};
      if (shopName != null) body['shop_name'] = shopName;
      if (ownerName != null) body['owner_name'] = ownerName;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;
      if (lat != null) body['lat'] = lat;
      if (lng != null) body['lng'] = lng;
      if (openTime != null || closeTime != null) {
        body['operating_hours'] = {
          'open': openTime ?? _store!.operatingHours?.open ?? '09:00',
          'close': closeTime ?? _store!.operatingHours?.close ?? '22:00',
        };
      }

      await _api.patch('/stores/me/profile', body: body);

      // Optimistic local update so UI reflects changes immediately
      final newLoc = (lat != null || lng != null)
          ? StoreLocation(
              lat: lat ?? _store!.location.lat,
              lng: lng ?? _store!.location.lng,
            )
          : null;
      final newHours = (openTime != null || closeTime != null)
          ? OperatingHours(
              open: openTime ?? _store!.operatingHours?.open ?? '09:00',
              close: closeTime ?? _store!.operatingHours?.close ?? '22:00',
            )
          : null;
      _store = _store!.copyWith(
        shopName: shopName,
        ownerName: ownerName,
        phone: phone,
        address: address,
        location: newLoc,
        operatingHours: newHours,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
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
