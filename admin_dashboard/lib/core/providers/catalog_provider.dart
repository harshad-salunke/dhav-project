import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/catalog_item.dart';

class CatalogProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<AdminCatalogItem> items = [];
  bool isLoading = false;
  String? error;
  bool showInactive = false;

  List<String> get categories {
    final cats = items.map((i) => i.category).toSet().toList();
    cats.sort();
    return cats;
  }

  Future<void> loadItems({String? search, String? category}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final query = <String, String>{};
      if (showInactive) query['include_inactive'] = 'true';
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (category != null && category.isNotEmpty) query['category'] = category;

      final data = await _api.get('/admin/catalog/items', query: query);
      items = (data['items'] as List)
          .map((i) => AdminCatalogItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createItem(Map<String, dynamic> payload) async {
    try {
      await _api.post('/admin/catalog/items', body: payload);
      await loadItems();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateItem(String itemId, Map<String, dynamic> payload) async {
    try {
      await _api.patch('/admin/catalog/items/$itemId', body: payload);
      await loadItems();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleActive(String itemId, bool makeActive) async {
    try {
      await _api.patch('/admin/catalog/items/$itemId',
          body: {'is_active': makeActive});
      await loadItems();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(String itemId, {bool permanent = false}) async {
    try {
      await _api.delete(
          '/admin/catalog/items/$itemId${permanent ? '?permanent=true' : ''}');
      await loadItems();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void toggleShowInactive() {
    showInactive = !showInactive;
    loadItems();
  }
}
