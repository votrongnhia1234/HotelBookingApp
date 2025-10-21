import '../config/api_constants.dart';
import '../models/dashboard_stats.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';

class AdminService {
  AdminService() : _api = ApiService();

  final ApiService _api;

  Future<DashboardStats> fetchDashboard() async {
    final raw = await _api.get(ApiConstants.adminDashboard);
    final mapped = ApiDataParser.map(raw);
    return DashboardStats.fromJson(Map<String, dynamic>.from(mapped));
  }
}
