import '../config/api_constants.dart';
import 'api_service.dart';

class AiService {
  final ApiService _api = ApiService();

  Future<String> chat({
    required String message,
    List<Map<String, String>>? history,
    String? contextType,
    String? city,
    int? limit,
    String? checkIn,
    String? checkOut,
    int? hotelId,
  }) async {
    // Chuẩn hóa history: loại bỏ tin nhắn user vừa gửi để tránh trùng với 'message'
    List<Map<String, String>>? normalized;
    if (history != null) {
      normalized = List<Map<String, String>>.from(history);
      if (normalized.isNotEmpty && (normalized.last['role'] == 'user')) {
        normalized.removeLast();
      }
    }

    final body = {
      'message': message,
      if (normalized != null) 'messages': normalized,
      if (contextType != null) 'contextType': contextType,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (limit != null) 'limit': limit,
      if (checkIn != null && checkIn.trim().isNotEmpty)
        'checkIn': checkIn.trim(),
      if (checkOut != null && checkOut.trim().isNotEmpty)
        'checkOut': checkOut.trim(),
      if (hotelId != null) 'hotelId': hotelId,
    };
    final resp = await _api.post(ApiConstants.aiChat, body);
    // Hỗ trợ nhiều dạng cấu trúc JSON khác nhau từ API
    dynamic data = resp;
    if (data is Map && data['data'] is Map) {
      data = data['data'];
    }
    String? content;
    if (data is Map) {
      content = (data['content'] ?? data['message'] ?? data['answer'])
          ?.toString();
      // Hỗ trợ dạng OpenAI: { choices: [ { message: { content } } ] }
      if (content == null) {
        final choices = data['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map) {
            final msg = first['message'];
            if (msg is Map && msg['content'] != null) {
              content = msg['content'].toString();
            }
          }
        }
      }
    }
    return content ?? resp.toString();
  }
}
