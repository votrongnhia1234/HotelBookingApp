import '../config/api_constants.dart';
import '../models/voucher.dart';
import '../state/auth_state.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';

class VoucherService {
  final ApiService _api = ApiService();

  Future<List<Voucher>> listForCurrentUser() async {
    final user = AuthState.I.currentUser;
    if (user == null) return const [];

    final raw = await _api.get('${ApiConstants.vouchers}?userId=${user.id}');
    return ApiDataParser.list(raw)
        .map((e) => Voucher.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
