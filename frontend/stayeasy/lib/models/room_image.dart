import '../config/api_constants.dart';

class RoomImage {
  final int id;
  final int roomId;
  final String imageUrl;
  final DateTime? createdAt;

  RoomImage({
    required this.id,
    required this.roomId,
    required this.imageUrl,
    this.createdAt,
  });

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final asDouble = double.tryParse(value);
      if (asDouble != null) return asDouble.toInt();
    }
    return 0;
  }

  static String _toStr(dynamic value) => value?.toString() ?? '';

  static DateTime? _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory RoomImage.fromJson(Map<String, dynamic> json) => RoomImage(
        id: _toInt(json['id']),
        roomId: _toInt(json['room_id'] ?? json['roomId']),
        imageUrl: ApiConstants.resolveFileUrl(
          _toStr(json['image_url'] ?? json['imageUrl'] ?? json['url'] ?? json['path'] ?? ''),
        ),
        createdAt: _toDate(json['created_at'] ?? json['createdAt']),
      );
}
