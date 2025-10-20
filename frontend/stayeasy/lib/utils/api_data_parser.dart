class ApiDataParser {
  static List list(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      for (final k in const ['data', 'rows', 'items', 'result', 'results', 'rooms', 'reviews']) {
        final v = body[k];
        if (v is List) return v;
      }
    }
    return [];
  }

  static Map<String, dynamic> map(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return {'data': body};
  }

  static Map<String, dynamic> asMap(dynamic body) => map(body);
  static List asList(dynamic body) => list(body);
}
