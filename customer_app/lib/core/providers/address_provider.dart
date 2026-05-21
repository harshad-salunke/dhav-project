import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/saved_address.dart';
import '../services/api_client.dart';

class AddressProvider extends ChangeNotifier {
  List<SavedAddress> _addresses = [];
  SavedAddress? _selected;
  bool _loading = false;
  String? _error;

  List<SavedAddress> get addresses => List.unmodifiable(_addresses);
  SavedAddress? get selected => _selected;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadAddresses() async {
    _loading = true;
    notifyListeners();
    try {
      final resp = await ApiClient.get('/customers/me');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final raw = body['saved_addresses'];
        if (raw is List) {
          _addresses = raw
              .whereType<Map<String, dynamic>>()
              .map(SavedAddress.fromJson)
              .toList();
        }
        if (_selected == null && _addresses.isNotEmpty) {
          _selected = _addresses.first;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addAddress(SavedAddress address) async {
    try {
      final resp =
          await ApiClient.post('/customers/me/addresses', address.toJson());
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await loadAddresses();
        if (_addresses.isNotEmpty) {
          _selected = _addresses.last;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }
    return false;
  }

  Future<bool> deleteAddress(int index) async {
    try {
      final wasSelectedIndex = _selected != null &&
          index < _addresses.length &&
          _selected!.lat == _addresses[index].lat &&
          _selected!.lng == _addresses[index].lng &&
          _selected!.flatBuilding == _addresses[index].flatBuilding;
      final resp =
          await ApiClient.delete('/customers/me/addresses/$index');
      if (resp.statusCode == 200) {
        if (wasSelectedIndex) _selected = null;
        await loadAddresses();
        if (_selected == null && _addresses.isNotEmpty) {
          _selected = _addresses.first;
        }
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }
    return false;
  }

  Future<bool> editAddress(int index, SavedAddress address) async {
    try {
      final resp = await ApiClient.patch(
          '/customers/me/addresses/$index', address.toJson());
      if (resp.statusCode == 200) {
        final wasSelected = _selected != null &&
            index < _addresses.length &&
            _selected!.lat == _addresses[index].lat &&
            _selected!.lng == _addresses[index].lng &&
            _selected!.flatBuilding == _addresses[index].flatBuilding;
        await loadAddresses();
        if (wasSelected && index < _addresses.length) {
          _selected = _addresses[index];
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }
    return false;
  }

  void selectAddress(SavedAddress address) {
    _selected = address;
    notifyListeners();
  }

  void clearSelected() {
    _selected = null;
    notifyListeners();
  }
}
