import 'package:flutter/foundation.dart';

import '../models/catalog_item.dart';
import '../services/api_client.dart';

class InventoryProvider extends ChangeNotifier {
  InventoryProvider({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  List<CatalogItem> _catalog = [];
  List<String> _categories = [];
  Set<String> _available = {};
  String _searchQuery = '';
  String? _activeCategory;
  bool _loading = false;
  String? _error;

  List<CatalogItem> get catalog => _filter(_catalog);
  List<String> get categories => _categories;
  Set<String> get available => _available;
  bool get loading => _loading;
  String? get error => _error;
  String? get activeCategory => _activeCategory;
  String get searchQuery => _searchQuery;

  List<CatalogItem> _filter(List<CatalogItem> all) {
    return all.where((i) {
      if (_activeCategory != null && i.category != _activeCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!i.name.toLowerCase().contains(q) &&
            !(i.nameHindi?.toLowerCase().contains(q) ?? false) &&
            !(i.nameMarathi?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setCategory(String? category) {
    _activeCategory = category;
    notifyListeners();
  }

  Future<void> load({required List<String> initialAvailable}) async {
    _loading = true;
    _error = null;
    _available = initialAvailable.toSet();
    notifyListeners();
    try {
      final cats = await _api.get('/catalog/categories', requireAuth: false)
          as Map<String, dynamic>;
      _categories =
          (cats['categories'] as List? ?? []).map((e) => e.toString()).toList();

      final items = await _api.get('/catalog/items',
          query: {'limit': 200}, requireAuth: false) as Map<String, dynamic>;
      _catalog = (items['items'] as List? ?? [])
          .map((e) => CatalogItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void toggleLocal(String itemId) {
    if (_available.contains(itemId)) {
      _available.remove(itemId);
    } else {
      _available.add(itemId);
    }
    notifyListeners();
  }

  Future<void> saveToBackend() async {
    await _api.patch('/stores/me/inventory', body: {
      'available_item_ids': _available.toList(),
    });
  }
}
