import '../models/voucher.dart';
// import 'api_service.dart'; // nếu sau này có API thật

class VoucherService {
  // final _api = ApiService();

  /// Tạm thời mock vài voucher hợp lệ
  Future<List<Voucher>> listForUser(int userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Voucher(
        id: 1,
        code: 'WEEKEND10',
        title: 'Giảm 10% cuối tuần',
        description: 'Áp dụng mọi hình thức thanh toán.',
        discountType: 'percent',
        value: 10,
        minOrder: 500000,
      ),
      Voucher(
        id: 2,
        code: 'ONLINE50K',
        title: 'Giảm 50.000 khi thanh toán online',
        description: 'Chỉ áp dụng khi thanh toán trực tuyến.',
        discountType: 'amount',
        value: 50000,
        onlineOnly: true,
        minOrder: 200000,
      ),
    ];
  }
}
