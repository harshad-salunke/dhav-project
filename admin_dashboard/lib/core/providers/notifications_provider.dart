import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class AdminNotificationsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool isSending = false;
  bool sendSuccess = false;
  String? error;
  Map<String, dynamic>? lastResult;

  // Recent history (optional admin view)
  List<Map<String, dynamic>> recentHistory = [];
  bool historyLoading = false;

  Future<bool> broadcast({
    required String target,
    required String title,
    required String message,
    required String type,
    String? storeId,
    String? customerUid,
  }) async {
    isSending = true;
    sendSuccess = false;
    error = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'target': target,
        'title': title,
        'message': message,
        'type': type,
        if (storeId != null) 'store_id': storeId,
        if (customerUid != null) 'customer_uid': customerUid,
      };
      final result = await _api.post('/admin/notifications/broadcast', body: body);
      lastResult = Map<String, dynamic>.from(result as Map);
      sendSuccess = true;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory({String? uid}) async {
    historyLoading = true;
    notifyListeners();
    try {
      final query = <String, String>{};
      if (uid != null) query['uid'] = uid;
      final data = await _api.get('/admin/notifications/history', query: query);
      final list = (data['notifications'] as List?) ?? [];
      recentHistory = list.map((n) => Map<String, dynamic>.from(n as Map)).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      historyLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    sendSuccess = false;
    error = null;
    lastResult = null;
    notifyListeners();
  }
}
