import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

class ApiClient {
  final String _base = ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    _checkStatus(res);
    return jsonDecode(res.body);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.post(uri,
        headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    _checkStatus(res);
    return jsonDecode(res.body);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.patch(uri,
        headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    _checkStatus(res);
    return jsonDecode(res.body);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.put(uri,
        headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    _checkStatus(res);
    return jsonDecode(res.body);
  }

  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.delete(uri, headers: await _headers());
    _checkStatus(res);
    return jsonDecode(res.body);
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
  }
}
