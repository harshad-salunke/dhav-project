import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin HTTP wrapper that injects the current Firebase user's ID token as a
/// Bearer header on every call. Throws [ApiException] on non-2xx responses.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<Map<String, String>> _headers({bool requireAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requireAuth) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ApiException(401, 'Not signed in');
      }
      final token = await user.getIdToken();
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool requireAuth = true}) async {
    final res = await _http
        .get(_uri(path, query), headers: await _headers(requireAuth: requireAuth))
        .timeout(ApiConfig.requestTimeout);
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body, bool requireAuth = true}) async {
    final res = await _http
        .post(_uri(path),
            headers: await _headers(requireAuth: requireAuth),
            body: body == null ? null : jsonEncode(body))
        .timeout(ApiConfig.requestTimeout);
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Object? body, bool requireAuth = true}) async {
    final res = await _http
        .patch(_uri(path),
            headers: await _headers(requireAuth: requireAuth),
            body: body == null ? null : jsonEncode(body))
        .timeout(ApiConfig.requestTimeout);
    return _decode(res);
  }

  Future<dynamic> delete(String path, {bool requireAuth = true}) async {
    final res = await _http
        .delete(_uri(path), headers: await _headers(requireAuth: requireAuth))
        .timeout(ApiConfig.requestTimeout);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final detail = (body is Map && body['detail'] != null) ? body['detail'].toString() : res.body;
    throw ApiException(res.statusCode, detail);
  }
}
