import '../config/api_constants.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';

class PaymentIntentResult {
  PaymentIntentResult({this.clientSecret, this.status, this.amount});

  final String? clientSecret;
  final String? status;
  final double? amount;

  bool get requiresStripeSheet => clientSecret != null;
}

class PaymentService {
  PaymentService(this._apiService);
  final ApiService _apiService;

  Future<PaymentIntentResult> createPayment({
    required int bookingId,
    required double amount,
    required String method, // 'cod' | 'online'
    String currency = 'vnd',
  }) async {
    final response = await _apiService.post(ApiConstants.payments, {
      'booking_id': bookingId,
      'amount': amount,
      'method': method,
      'currency': currency,
    });

    final map = ApiDataParser.asMap(response);

    if (map['clientSecret'] != null) {
      return PaymentIntentResult(clientSecret: map['clientSecret']?.toString());
    }

    final inner = Map<String, dynamic>.from(map['data'] ?? map);
    final amountValue = inner['amount'];
    return PaymentIntentResult(
      status: inner['status']?.toString(),
      amount: amountValue is num ? amountValue.toDouble() : null,
    );
  }
}
