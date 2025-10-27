import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConstants {
  ApiConstants._();

  // Optional overrides via --dart-define
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _apiOriginOverride = String.fromEnvironment('API_ORIGIN', defaultValue: '');

  // Base API url (includes /api segment)
  static String get baseUrl {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    if (_apiOriginOverride.isNotEmpty) return '$_apiOriginOverride/api';
    if (kIsWeb) return 'http://localhost:4000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api';
    }
    return 'http://127.0.0.1:4000/api';
  }

  // Origin host without /api, used for static files like /uploads
  static String get origin {
    if (_apiOriginOverride.isNotEmpty) return _apiOriginOverride;
    if (kIsWeb) return 'http://localhost:4000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000';
    }
    return 'http://127.0.0.1:4000';
  }

  // Resolve relative file/image paths to absolute URLs against server origin
  static String resolveFileUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '$origin$value';
    return '$origin/$value';
  }

  // Hotels
  static const String hotels = '/hotels';
  static const String managedHotels = '/hotels/managed';
  // Hotel images
  static String hotelImagesByHotel(int hotelId) => '/hotels/$hotelId/images';
  static String hotelImageById(int imageId) => '/hotels/images/$imageId';
  static const String hotelImages = '/hotels/images';
  static const String hotelImagesUpload = '/hotels/images/upload';
  static const String hotelImagesUploadMany = '/hotels/images/upload-many';

  // Rooms
  static String roomsByHotel(int hotelId) => '/rooms/hotel/$hotelId';
  static String managedRoomsByHotel(int hotelId) => '/rooms/managed/$hotelId';
  static String roomImagesByRoom(int roomId) => '/rooms/$roomId/images';
  static String roomImageById(int imageId) => '/rooms/images/$imageId';
  static String roomBookingsByRoom(int roomId) => '/rooms/$roomId/bookings';
  static const String rooms = '/rooms';
  static String roomStatus(int roomId) => '/rooms/$roomId/status';
  static const String roomImages = '/rooms/images';
  static const String roomImagesUpload = '/rooms/images/upload';
  // Add bulk upload endpoint
  static const String roomImagesUploadMany = '/rooms/images/upload-many';

  // Users
  static const String userProfile = '/users/me';
  static const String userTransactions = '/users/me/transactions';

  // Bookings
  static const String bookings = '/bookings';
  static const String bookingsSummary = '/bookings/summary';
  static const String bookingsSummaryExport = '/bookings/summary/export';
  static String bookingsByUser(int userId) => '/bookings?userId=$userId';
  static String cancelBooking(int bookingId) => '/bookings/$bookingId/cancel';
  static String updateBookingStatus(int bookingId) => '/bookings/$bookingId/status';
  static String completeBooking(int bookingId) => '/bookings/$bookingId/complete';

  // Payments
  static const String payments = '/payments';
  static const String paymentsConfirmDemo = '/payments/confirm-demo';
  static const String vouchers = '/vouchers';

  // Admin
  static const String adminDashboard = '/admin/stats/dashboard';
  static const String adminExportRevenueSummary = '/admin/stats/revenue/export-summary';
  static const String adminExportRevenue = '/admin/stats/revenue/export';
  // NEW: Admin listings
  static const String adminUsers = '/admin/users';
  static const String adminBookings = '/admin/bookings';
  // AI Chat
  static const String aiChat = '/ai/chat';
  // NEW: Admin user role & hotel manager assignment
  static String adminChangeUserRole(int userId) => '/admin/users/$userId/role';
  static String adminAssignHotelManager(int hotelId) => '/admin/hotels/$hotelId/managers';
  static String adminRemoveHotelManager(int hotelId, int userId) => '/admin/hotels/$hotelId/managers/$userId';
  static String adminListHotelManagers(int hotelId) => '/admin/hotels/$hotelId/managers';
  static const String adminExportHotelManagers = '/admin/hotel-managers/export';
  static String adminExportHotelManagersByHotel(int hotelId) => '/admin/hotels/$hotelId/managers/export';
  // NEW: Admin hotels CRUD
  static const String adminHotels = '/admin/hotels';
  static String adminHotelById(int id) => '/admin/hotels/$id';

  // Cities & attractions
  static String cityAttractions(String city) =>
      '/cities/${Uri.encodeComponent(city)}/attractions/photos';

  // Reviews
  static String reviewsGetByHotel(int hotelId) => '/reviews/hotel/$hotelId';
  static const String reviews = '/reviews';
}
