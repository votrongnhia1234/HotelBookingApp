import '../config/api_constants.dart';

class Room {
  final int id;
  final int hotelId;
  final String roomNumber;
  final String type;
  final int pricePerNight;
  final String status;
  final String imageUrl;

  Room({
    required this.id,
    required this.hotelId,
    required this.roomNumber,
    required this.type,
    required this.pricePerNight,
    required this.status,
    this.imageUrl = '',
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final i = int.tryParse(v);
      if (i != null) return i;
      final d = double.tryParse(v);
      if (d != null) return d.toInt();
    }
    return 0;
  }

  static String _toStr(dynamic v) => v?.toString() ?? '';

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: _toInt(j['id']),
        hotelId: _toInt(j['hotelId'] ?? j['hotel_id'] ?? 0),
        roomNumber: _toStr(j['roomNumber'] ?? j['room_number'] ?? j['number']),
        type: _toStr(j['type'] ?? j['roomType'] ?? j['room_type']),
        pricePerNight: _toInt(
          j['pricePerNight'] ?? j['price_per_night'] ?? j['price'] ?? j['amount'],
        ),
        status: _toStr(
          j['status'] ?? j['availability'] ?? j['state'] ?? 'available',
        ),
        // Prefer images array (first entry) if available, otherwise fall back to single image fields
        imageUrl: ApiConstants.resolveFileUrl(() {
          if (j['images'] is List && (j['images'] as List).isNotEmpty) {
            final first = (j['images'] as List).first;
            return _toStr(
              first is Map ? first['url'] ?? first['src'] ?? first['path'] : first,
            );
          }
          return _toStr(
            j['image_url'] ?? j['imageUrl'] ?? j['photo'] ?? j['thumbnail'],
          );
        }()),
      );

  String? get thumbnailUrl => imageUrl.isNotEmpty ? imageUrl : null;
}
