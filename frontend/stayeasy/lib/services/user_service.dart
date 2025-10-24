import '../config/api_constants.dart';
import '../models/booking.dart';
import '../models/profile_info.dart';
import '../models/user.dart';
import '../state/auth_state.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';

class UserService {
  final ApiService _api = ApiService();

  Future<ProfileInfo> fetchProfile() async {
    final raw = await _api.get(ApiConstants.userProfile);
    final map = ApiDataParser.map(raw);
    final data = Map<String, dynamic>.from(map['data'] ?? map);
    return ProfileInfo.fromJson(data);
  }

  Future<ProfileInfo> updateProfile({
    String? name,
    String? phone,
    String? address,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (address != null) body['address'] = address;

    final raw = await _api.patch(ApiConstants.userProfile, body);
    final map = ApiDataParser.map(raw);
    final data = Map<String, dynamic>.from(map['data'] ?? map);
    final profile = ProfileInfo.fromJson(data);

    final updatedUser = User(
      id: profile.id,
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      role: profile.role,
    );
    await AuthState.I.updateUser(updatedUser);
    return profile;
  }

  Future<List<Booking>> fetchTransactions() async {
    final raw = await _api.get(ApiConstants.userTransactions);
    return ApiDataParser.list(raw)
        .map((e) => Booking.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
