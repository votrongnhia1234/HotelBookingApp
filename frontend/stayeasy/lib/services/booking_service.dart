import '../config/api_constants.dart';
import '../models/booking.dart';
import '../models/booking_summary.dart';
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

  Future<List<Booking>> fetchAllBookings() async {
    final raw = await _api.get(ApiConstants.bookings);
    return ApiDataParser.list(raw)
        .map((e) => Booking.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Booking> createBooking({
    required int roomId,
    required String checkIn,
    required String checkOut,
  }) async {
    final raw = await _api.post(ApiConstants.bookings, {
      'room_id': roomId,
      'check_in': checkIn,
      'check_out': checkOut,
    });
    final map = ApiDataParser.map(raw);
    final payload = Map<String, dynamic>.from(map['data'] ?? map);
    return Booking.fromJson(payload);
  }

  Future<void> cancelBooking(int bookingId) async {
    await _api.patch(ApiConstants.cancelBooking(bookingId), {});
  }

  Future<void> updateStatus(int bookingId, String status) async {
    await _api.patch(ApiConstants.updateBookingStatus(bookingId), {
      'status': status,
    });
  }

  Future<void> complete(int bookingId) async {
    await _api.patch(ApiConstants.completeBooking(bookingId), {});
  }

  Future<({String role, BookingSummary summary})> fetchSummary() async {
    final raw = await _api.get('${ApiConstants.bookings}/summary');
    final mapped = ApiDataParser.map(raw);
    final summaryJson = Map<String, dynamic>.from(mapped['summary'] ?? {});
    return (
      role: mapped['role']?.toString() ?? '',
      summary: BookingSummary.fromJson(summaryJson),
    );
  }

  // ===== Export partner booking summary =====
  Future<void> exportSummary({String? from, String? to, String format = 'xlsx'}) async {
    final params = <String>[];
    if (from != null && from.isNotEmpty) params.add('from=$from');
    if (to != null && to.isNotEmpty) params.add('to=$to');
    if (format.isNotEmpty) params.add('format=$format');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    await _api.download('${ApiConstants.bookingsSummaryExport}$query');
  }

  Future<void> exportSummaryXlsx({String? from, String? to}) async {
    await exportSummary(from: from, to: to, format: 'xlsx');
  }

  Future<void> exportSummaryCsv({String? from, String? to}) async {
    await exportSummary(from: from, to: to, format: 'csv');
  }
}
