import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
import '../state/auth_state.dart';
import 'download_stub.dart'
    if (dart.library.html) 'download_web.dart'
    as platform_download;

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

  // Common headers without Content-Type (safe for GET/DELETE, avoids preflight)
  Map<String, String> _headersCommon([Map<String, String>? extra]) {
    final t = AuthState.I.token;
    return {
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
      ...?extra,
    };
  }

  // JSON headers for requests with a body (POST/PATCH)
  Map<String, String> _headersJson([Map<String, String>? extra]) {
    return {'Content-Type': 'application/json', ..._headersCommon(extra)};
  }

  Future<dynamic> get(String path, {Map<String, String>? headers}) async {
    final url = _build(path);
    if (_log) dev.log('[GET] $url', name: 'ApiService');
    // Avoid Content-Type on GET to keep it a simple request (no preflight)
    final resp = await http.get(
      url,
      headers: _headersCommon({'Accept': 'application/json', ...?headers}),
    );
    if (_log) {
      dev.log('[GET] ${resp.statusCode} ${resp.body}', name: 'ApiService');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final url = _build(path);
    if (_log) dev.log('[POST] $url\nBody: $body', name: 'ApiService');
    final resp = await http.post(
      url,
      headers: _headersJson(headers),
      body: jsonEncode(body),
    );
    if (_log) {
      dev.log('[POST] ${resp.statusCode} ${resp.body}', name: 'ApiService');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final url = _build(path);
    if (_log) dev.log('[PATCH] $url\nBody: $body', name: 'ApiService');
    final resp = await http.patch(
      url,
      headers: _headersJson(headers),
      body: jsonEncode(body),
    );
    if (_log) {
      dev.log('[PATCH] ${resp.statusCode} ${resp.body}', name: 'ApiService');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  Future<dynamic> uploadFile(
    String path,
    String fieldName,
    String filePath, {
    Map<String, String>? fields,
    String method = 'POST',
  }) async {
    final url = _build(path);
    final request = http.MultipartRequest(method.toUpperCase(), url);
    request.headers.addAll(
      _headersCommon({'Content-Type': 'multipart/form-data'}),
    );
    if (fields != null) request.fields.addAll(fields);
    final file = await http.MultipartFile.fromPath(fieldName, filePath);
    request.files.add(file);
    if (_log) {
      dev.log(
        '[UPLOAD $method] $url fields=${fields ?? {}}',
        name: 'ApiService',
      );
    }
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (_log) {
      dev.log(
        '[UPLOAD $method] ${resp.statusCode} ${resp.body}',
        name: 'ApiService',
      );
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  // Upload multiple files with the same field name (e.g. 'files')
  Future<dynamic> uploadFiles(
    String path,
    List<String> filePaths, {
    String fieldName = 'files',
    Map<String, String>? fields,
  }) async {
    final url = _build(path);
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(
      _headersCommon({'Content-Type': 'multipart/form-data'}),
    );
    if (fields != null) request.fields.addAll(fields);
    for (final fp in filePaths) {
      final f = await http.MultipartFile.fromPath(fieldName, fp);
      request.files.add(f);
    }
    if (_log) {
      dev.log(
        '[UPLOAD MANY] $url files=${filePaths.length} fields=${fields ?? {}}',
        name: 'ApiService',
      );
    }
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (_log) {
      dev.log(
        '[UPLOAD MANY] ${resp.statusCode} ${resp.body}',
        name: 'ApiService',
      );
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  Future<dynamic> delete(String path, {Map<String, String>? headers}) async {
    final url = _build(path);
    if (_log) dev.log('[DELETE] $url', name: 'ApiService');
    // Avoid Content-Type on DELETE to keep it simple
    final resp = await http.delete(url, headers: _headersCommon(headers));
    if (_log) {
      dev.log('[DELETE] ${resp.statusCode} ${resp.body}', name: 'ApiService');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  // Upload single file from bytes (web-friendly)
  Future<dynamic> uploadFileBytes(
    String path,
    String fieldName,
    Uint8List bytes, {
    String? filename,
    Map<String, String>? fields,
    String method = 'POST',
  }) async {
    final url = _build(path);
    final request = http.MultipartRequest(method.toUpperCase(), url);
    request.headers.addAll(
      _headersCommon({'Content-Type': 'multipart/form-data'}),
    );
    if (fields != null) request.fields.addAll(fields);
    final fn =
        filename ?? 'upload_${DateTime.now().millisecondsSinceEpoch}.bin';
    final file = http.MultipartFile.fromBytes(fieldName, bytes, filename: fn);
    request.files.add(file);
    if (_log) {
      dev.log(
        '[UPLOAD BYTES $method] $url fields=${fields ?? {}} name=$fn',
        name: 'ApiService',
      );
    }
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (_log) {
      dev.log(
        '[UPLOAD BYTES $method] ${resp.statusCode} ${resp.body}',
        name: 'ApiService',
      );
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  // Upload multiple files from bytes (web-friendly)
  Future<dynamic> uploadFilesBytes(
    String path,
    List<Uint8List> filesBytes, {
    List<String>? fileNames,
    String fieldName = 'files',
    Map<String, String>? fields,
  }) async {
    final url = _build(path);
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(
      _headersCommon({'Content-Type': 'multipart/form-data'}),
    );
    if (fields != null) request.fields.addAll(fields);
    for (int i = 0; i < filesBytes.length; i++) {
      final bytes = filesBytes[i];
      final name =
          (fileNames != null && i < fileNames.length && fileNames[i].isNotEmpty)
          ? fileNames[i]
          : 'upload_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.bin';
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: name),
      );
    }
    if (_log) {
      dev.log(
        '[UPLOAD MANY BYTES] $url count=${filesBytes.length} fields=${fields ?? {}}',
        name: 'ApiService',
      );
    }
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (_log) {
      dev.log(
        '[UPLOAD MANY BYTES] ${resp.statusCode} ${resp.body}',
        name: 'ApiService',
      );
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  // ===== File download (web) =====
  Future<void> download(String path, {String? filename}) async {
    final url = _build(path);
    if (_log) dev.log('[DOWNLOAD] $url', name: 'ApiService');
    final resp = await http.get(
      url,
      headers: _headersCommon({'Accept': '*/*'}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final bytes = resp.bodyBytes;
      final contentType =
          resp.headers['content-type'] ?? 'application/octet-stream';
      final suggested = _filenameFromDisposition(
        resp.headers['content-disposition'],
      );
      final name =
          filename ??
          suggested ??
          'download_${DateTime.now().millisecondsSinceEpoch}';
      // Delegate to platform-specific implementation (web triggers browser download, others no-op)
      await platform_download.triggerDownload(bytes, contentType, name);
      if (_log) dev.log('[DOWNLOAD] started file=$name', name: 'ApiService');
      return;
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  String? _filenameFromDisposition(String? disposition) {
    if (disposition == null) return null;
    final m = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return m?.group(1);
  }
}
