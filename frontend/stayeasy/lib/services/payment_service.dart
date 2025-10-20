import '../config/api_constants.dart';
import '../models/payment.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';

class PaymentService {
  PaymentService(this._apiService);
  final ApiService _apiService;

  Future<Payment> createPayment({
    required int bookingId,
    required double amount,
    required String method, // 'cod' | 'online'
  }) async {
    final resp = await _apiService.post(ApiConstants.payments, {
      'booking_id': bookingId,
      'amount': amount,
      'method': method,
    });

    // Chuẩn hoá: server có thể trả thẳng object hoặc bọc trong {data}/ {payment}
    final m = ApiDataParser.asMap(resp);
    final inner = m['payment'] ?? m['data'] ?? m;
    return Payment.fromJson(Map<String, dynamic>.from(inner));
  }
}
