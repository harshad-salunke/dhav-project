import 'package:flutter/foundation.dart';

import '../models/settlement.dart';
import '../services/api_client.dart';

class EarningsProvider extends ChangeNotifier {
  EarningsProvider({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  WeeklySettlement? _current;
  List<WeeklySettlement> _history = [];
  bool _loading = false;
  String? _error;

  WeeklySettlement? get current => _current;
  List<WeeklySettlement> get history => _history;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final cur = await _api.get('/settlements/store/current')
          as Map<String, dynamic>;
      _current = cur['settlement'] == null
          ? null
          : WeeklySettlement.fromJson(
              Map<String, dynamic>.from(cur['settlement'] as Map));

      final hist = await _api.get('/settlements/store/history')
          as Map<String, dynamic>;
      _history = (hist['settlements'] as List? ?? [])
          .map((e) =>
              WeeklySettlement.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
