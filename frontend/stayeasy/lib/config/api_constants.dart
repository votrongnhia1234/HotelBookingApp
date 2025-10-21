import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:4000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:4000/api';
    return 'http://127.0.0.1:4000/api';
  }

  // Hotels
  static const String hotels = '/hotels';

  // Rooms
  static String roomsByHotel(int hotelId) => '/rooms/hotel/$hotelId';
  static const String rooms = '/rooms';
  static String roomStatus(int roomId) => '/rooms/$roomId/status';
  static const String roomImages = '/rooms/images';

  // Bookings
  static const String bookings = '/bookings';
  static String bookingsByUser(int userId) => '/bookings?userId=$userId';
  static String cancelBooking(int bookingId) => '/bookings/$bookingId/cancel';

  // Payments
  static const String payments = '/payments';
  static const String vouchers = '/vouchers';

  // Admin
  static const String adminDashboard = '/admin/stats/dashboard';

  // Cities & attractions
  static String cityAttractions(String city) =>
      '/cities/${Uri.encodeComponent(city)}/attractions/photos';

  // Reviews
  static String reviewsGetByHotel(int hotelId) => '/reviews/hotel/$hotelId';
  static const String reviews = '/reviews';
}
