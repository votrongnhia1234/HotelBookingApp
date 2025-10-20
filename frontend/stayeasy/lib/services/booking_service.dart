import '../config/api_constants.dart';
import '../models/booking.dart';
import 'api_service.dart';
import '../utils/api_data_parser.dart';
import '../state/auth_state.dart';

class BookingService {
  final _api = ApiService();

  Future<List<Booking>> fetchBookingsForUser(int userId) async {
    final raw = await _api.get(ApiConstants.bookingsByUser(userId));
    return ApiDataParser.list(raw)
        .map((e) => Booking.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Booking> createBooking({
    required int roomId,
    required String checkIn,
    required String checkOut,
  }) async {
    final user = AuthState.I.currentUser;
    if (user == null) {
      throw Exception('UNAUTHENTICATED');
    }
    final body = {
      'room_id': roomId,
      'check_in': checkIn,
      'check_out': checkOut,
    };
    final raw = await _api.post(ApiConstants.bookings, body);
    final mapped = ApiDataParser.map(raw);
    return Booking.fromJson(Map<String, dynamic>.from(mapped['data'] ?? mapped));
  }

  Future<void> cancelBooking(int bookingId) async {
    await _api.patch(ApiConstants.cancelBooking(bookingId), {});
  }
}
