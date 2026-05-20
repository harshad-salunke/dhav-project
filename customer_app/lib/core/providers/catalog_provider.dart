import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/catalog_item.dart';
import '../services/api_client.dart';

class CatalogProvider extends ChangeNotifier {
  List<CatalogItem> _allItems = [];
  Set<String> _nearbyItemIds = {};
  List<Map<String, dynamic>> _nearbyStores = [];
  List<Map<String, dynamic>> _allNearbyStores = [];
  List<CatalogCategory> _categories = [];
  bool _loading = false;
  String? _error;
  bool _hasLocation = false;
  int _storesFound = 0;
  double? _lat;
  double? _lng;

  /// All items, with isAvailable reflecting whether each item is in a nearby store.
  /// When no location is known, all active catalog items are returned as-is.
  List<CatalogItem> get items {
    if (!_hasLocation) return _allItems;
    return _allItems
        .map((i) => i.copyWith(isAvailable: _nearbyItemIds.contains(i.id)))
        .toList();
  }

  List<CatalogCategory> get categories => _categories;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasLocation => _hasLocation;
  int get storesFound => _storesFound;
  List<Map<String, dynamic>> get nearbyStores => _nearbyStores;
  List<Map<String, dynamic>> get allNearbyStores => _allNearbyStores;
  double? get userLat => _lat;
  double? get userLng => _lng;

  Future<void> loadCatalog({double? lat, double? lng}) async {
    _loading = true;
    _error = null;
    if (lat != null && lng != null) {
      _hasLocation = true;
      _lat = lat;
      _lng = lng;
    }
    notifyListeners();

    try {
      // Always load full catalog + categories
      final baseResults = await Future.wait([
        ApiClient.get('/catalog/items'),
        ApiClient.get('/catalog/categories'),
      ]);

      if (baseResults[0].statusCode == 200) {
        final body = jsonDecode(baseResults[0].body) as Map<String, dynamic>;
        final data = body['items'] as List? ?? [];
        _allItems = data
            .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (baseResults[1].statusCode == 200) {
        final body = jsonDecode(baseResults[1].body) as Map<String, dynamic>;
        final data = body['categories'] as List? ?? [];
        _categories = data
            .map((e) => CatalogCategory(id: e.toString(), name: e.toString()))
            .toList();
      }

      // When location is known, load nearby availability + store list
      if (_lat != null && _lng != null) {
        final nearbyResults = await Future.wait([
          ApiClient.get('/catalog/items/nearby?lat=$_lat&lng=$_lng&radius_km=10'),
          ApiClient.get('/catalog/stores/nearby?lat=$_lat&lng=$_lng&radius_km=10'),
          ApiClient.get('/catalog/stores/nearby/all?lat=$_lat&lng=$_lng&radius_km=10'),
        ]);

        if (nearbyResults[0].statusCode == 200) {
          final body =
              jsonDecode(nearbyResults[0].body) as Map<String, dynamic>;
          final data = body['items'] as List? ?? [];
          _nearbyItemIds = data
              .map((e) =>
                  (e as Map<String, dynamic>)['item_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
          _storesFound = (body['stores_found'] as int?) ?? 0;
        }

        if (nearbyResults[1].statusCode == 200) {
          final body =
              jsonDecode(nearbyResults[1].body) as Map<String, dynamic>;
          final data = body['stores'] as List? ?? [];
          _nearbyStores = List<Map<String, dynamic>>.from(data);
          if (_storesFound == 0) {
            _storesFound = (body['total'] as int?) ?? 0;
          }
        }

        if (nearbyResults[2].statusCode == 200) {
          final body =
              jsonDecode(nearbyResults[2].body) as Map<String, dynamic>;
          final data = body['stores'] as List? ?? [];
          _allNearbyStores = List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<CatalogItem> search(String query, {String? category}) {
    final q = query.toLowerCase();
    return items.where((item) {
      final matchesQuery = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          (item.nameHindi?.toLowerCase().contains(q) ?? false) ||
          (item.nameMarathi?.toLowerCase().contains(q) ?? false);
      final matchesCategory = category == null ||
          category.isEmpty ||
          item.category.toLowerCase() == category.toLowerCase();
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<String> get categoryNames {
    final names = items.map((i) => i.category).toSet().toList();
    names.sort();
    return names;
  }
}
