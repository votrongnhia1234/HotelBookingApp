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

  // ✅ ĐÚNG backend của bạn: /api/rooms/hotel/:id
  static String roomsByHotel(int hotelId) => '/rooms/hotel/$hotelId';

  // Bookings
  static const String bookings = '/bookings';
  static String bookingsByUser(int userId) => '/bookings?userId=$userId';

  // Payments
  static const String payments = '/payments';

  // Reviews
  static String reviewsGetByHotel(int hotelId) => '/reviews/hotel/$hotelId';
  static const String reviews = '/reviews';
}
