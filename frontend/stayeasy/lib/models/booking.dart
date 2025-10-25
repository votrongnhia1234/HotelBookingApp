import 'package:stayeasy/config/api_constants.dart';

class Booking {
  final int id;
  final int roomId;
  final int userId;
  final String checkIn;
  final String checkOut;
  final double totalAmount;
  final String status;
  final String roomNumber;
  final String roomType;
  final String hotelName;
  final double pricePerNight;
  final String imageUrl;

  Booking({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.checkIn,
    required this.checkOut,
    required this.totalAmount,
    required this.status,
    this.roomNumber = '',
    this.roomType = '',
    this.hotelName = '',
    this.pricePerNight = 0,
    this.imageUrl = '',
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
      final doubleParsed = double.tryParse(v);
      if (doubleParsed != null) return doubleParsed.toInt();
    }
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static String _toStr(dynamic v) => v?.toString() ?? '';

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: _toInt(json['id']),
        roomId: _toInt(json['room_id'] ?? json['roomId']),
        userId: _toInt(json['user_id'] ?? json['userId']),
        checkIn: _toStr(json['check_in'] ?? json['checkIn']),
        checkOut: _toStr(json['check_out'] ?? json['checkOut']),
        totalAmount: _toDouble(
          json['totalAmount'] ?? json['total_price'] ?? json['amount'],
        ),
        status: _toStr(json['status']),
        roomNumber: _toStr(json['room_number'] ?? json['roomNumber']),
        roomType: _toStr(json['room_type'] ?? json['roomType']),
        hotelName: _toStr(json['hotel_name'] ?? json['hotelName']),
        pricePerNight: _toDouble(json['price_per_night'] ?? json['pricePerNight']),
        imageUrl: ApiConstants.resolveFileUrl(
          _toStr(json['imageUrl'] ?? json['image_url'] ?? ''),
        ),
      );

  double get totalPrice => totalAmount;

  Booking copyWith({
    int? id,
    int? roomId,
    int? userId,
    String? checkIn,
    String? checkOut,
    double? totalAmount,
    String? status,
    String? roomNumber,
    String? roomType,
    String? hotelName,
    double? pricePerNight,
    String? imageUrl,
  }) {
    return Booking(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      hotelName: hotelName ?? this.hotelName,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
