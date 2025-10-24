import '../config/api_constants.dart';
import '../models/dashboard_stats.dart';
import '../models/user.dart';
import '../models/booking.dart';
import '../models/hotel.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';

class AdminService {
  AdminService() : _api = ApiService();

  final ApiService _api;

  Future<DashboardStats> fetchDashboard() async {
    final raw = await _api.get(ApiConstants.adminDashboard);
    final mapped = ApiDataParser.map(raw);
    return DashboardStats.fromJson(Map<String, dynamic>.from(mapped));
  }

  Future<void> exportRevenueSummaryXlsx() async {
    await _api.download('${ApiConstants.adminExportRevenueSummary}?format=xlsx');
  }

  Future<void> exportRevenueXlsx({
    required DateTime from,
    required DateTime to,
    String group = 'day',
  }) async {
    final f = DateFormat('yyyy-MM-dd').format(from);
    final t = DateFormat('yyyy-MM-dd').format(to);
    final path = '${ApiConstants.adminExportRevenue}?from=$f&to=$t&group=$group&format=xlsx';
    final filename = 'dataset_${f}_to_${t}_$group.xlsx';
    await _api.download(path, filename: filename);
  }

  // NEW: list all users (admin only)
  Future<List<User>> listUsers() async {
    final raw = await _api.get(ApiConstants.adminUsers);
    return ApiDataParser.list(raw)
        .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // NEW: list all bookings (admin only)
  Future<List<Booking>> listBookings({int? userId}) async {
    final path = userId == null
        ? ApiConstants.adminBookings
        : '${ApiConstants.adminBookings}?userId=$userId';
    final raw = await _api.get(path);
    return ApiDataParser.list(raw)
        .map((e) => Booking.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  
  // NEW: change user role
  Future<void> changeUserRole({required int userId, required String role}) async {
    await _api.patch(ApiConstants.adminChangeUserRole(userId), {
      'role': role,
    });
  }
  
  // NEW: hotel manager assignment
  Future<void> assignHotelManager({required int hotelId, required int userId}) async {
    await _api.post(ApiConstants.adminAssignHotelManager(hotelId), {
      'user_id': userId,
    });
  }
  
  Future<void> removeHotelManager({required int hotelId, required int userId}) async {
    await _api.delete(ApiConstants.adminRemoveHotelManager(hotelId, userId));
  }
  
  Future<List<User>> listManagersForHotel(int hotelId) async {
    final raw = await _api.get(ApiConstants.adminListHotelManagers(hotelId));
    final mapped = ApiDataParser.map(raw);
    final list = List<Map<String, dynamic>>.from(mapped['data'] ?? []);
    return list.map((e) => User.fromJson(e)).toList();
  }
  
  Future<void> exportHotelManagers({int? hotelId, String format = 'xlsx'}) async {
    final path = hotelId == null
        ? ApiConstants.adminExportHotelManagers
        : ApiConstants.adminExportHotelManagersByHotel(hotelId);
    final query = '?format=${Uri.encodeComponent(format)}';
    final filename = hotelId == null ? 'hotel_managers.$format' : 'hotel_${hotelId}_managers.$format';
    await _api.download('$path$query', filename: filename);
  }

  // NEW: Admin hotels CRUD
  Future<Hotel> createHotel({
    required String name,
    String? description,
    String? address,
    String? city,
    String? country,
    double? rating,
    double? latitude,
    double? longitude,
    String? imageUrl,
  }) async {
    final payload = {
      'name': name,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (rating != null) 'rating': rating,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (imageUrl != null) 'image_url': imageUrl,
    };
    final raw = await _api.post(ApiConstants.adminHotels, payload);
    final mapped = ApiDataParser.map(raw);
    final data = Map<String, dynamic>.from(mapped['data'] ?? mapped);
    return Hotel.fromJson(data);
  }

  Future<Hotel> updateHotel(int id, {
    String? name,
    String? description,
    String? address,
    String? city,
    String? country,
    double? rating,
    double? latitude,
    double? longitude,
    String? imageUrl,
  }) async {
    final payload = {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (rating != null) 'rating': rating,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (imageUrl != null) 'image_url': imageUrl,
    };
    final raw = await _api.patch(ApiConstants.adminHotelById(id), payload);
    final mapped = ApiDataParser.map(raw);
    final data = Map<String, dynamic>.from(mapped['data'] ?? mapped);
    return Hotel.fromJson(data);
  }

  Future<void> deleteHotel(int id) async {
    await _api.delete(ApiConstants.adminHotelById(id));
  }
}
