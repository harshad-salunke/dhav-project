import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/catalog_item.dart';
import '../services/api_client.dart';

class CatalogProvider extends ChangeNotifier {
  List<CatalogItem> _items = [];
  List<CatalogCategory> _categories = [];
  bool _loading = false;
  String? _error;

  List<CatalogItem> get items => _items;
  List<CatalogCategory> get categories => _categories;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadCatalog({double? lat, double? lng}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final path = lat != null && lng != null
          ? '/catalog/items/nearby?lat=$lat&lng=$lng'
          : '/catalog/items';

      final results = await Future.wait([
        ApiClient.get(path),
        ApiClient.get('/catalog/categories'),
      ]);

      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body) as List;
        _items = data
            .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body) as List;
        _categories = data
            .map((e) => CatalogCategory.fromJson(e as Map<String, dynamic>))
            .toList();
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
    return _items.where((item) {
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
    final names = _items.map((i) => i.category).toSet().toList();
    names.sort();
    return names;
  }
}
