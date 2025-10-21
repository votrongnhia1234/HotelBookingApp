import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
import '../state/auth_state.dart';

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);
  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiService {
  static const bool _log = true;

  Uri _build(String path) => Uri.parse('${ApiConstants.baseUrl}$path');

  Map<String, String> _headers([Map<String, String>? extra]) {
    final t = AuthState.I.token;
    return {
      'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
      ...?extra,
    };
  }

  Future<dynamic> get(String path, {Map<String, String>? headers}) async {
    final url = _build(path);
    if (_log) dev.log('[GET] $url', name: 'ApiService');
    final resp = await http.get(url, headers: _headers(headers));
    if (_log) dev.log('[GET] ${resp.statusCode} ${resp.body}', name: 'ApiService');
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    final url = _build(path);
    if (_log) dev.log('[POST] $url\nBody: $body', name: 'ApiService');
    final resp = await http.post(
      url,
      headers: _headers(headers),
      body: jsonEncode(body),
    );
    if (_log) dev.log('[POST] ${resp.statusCode} ${resp.body}', name: 'ApiService');
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    final url = _build(path);
    if (_log) dev.log('[PATCH] $url\nBody: $body', name: 'ApiService');
    final resp = await http.patch(
      url,
      headers: _headers(headers),
      body: jsonEncode(body),
    );
    if (_log) dev.log('[PATCH] ${resp.statusCode} ${resp.body}', name: 'ApiService');
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }
}
