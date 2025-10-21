class Hotel {
  final int id;
  final String name;
  final String address;
  final String city;
  final double rating;
  final String description;
  final String imageUrl;
  final double? latitude;
  final double? longitude;

  Hotel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.rating,
    required this.description,
    required this.imageUrl,
    this.latitude,
    this.longitude,
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final d = double.tryParse(v);
      if (d != null) return d.toInt();
      final i = int.tryParse(v);
      if (i != null) return i;
    }
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static String _toStr(dynamic v) => v?.toString() ?? '';

  static double? _toNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory Hotel.fromJson(Map<String, dynamic> j) => Hotel(
        id: _toInt(j['id'] ?? j['hotel_id']),
        name: _toStr(j['name'] ?? j['hotel_name']),
        address: _toStr(j['address'] ?? j['location']),
        city: _toStr(j['city'] ?? j['province'] ?? ''),
        rating: _toDouble(j['rating'] ?? j['avg_rating']),
        description: _toStr(j['description'] ?? j['desc']),
        imageUrl: _toStr(j['imageUrl'] ?? j['image_url'] ?? j['thumbnail']),
        latitude: _toNullableDouble(j['latitude'] ?? j['lat'] ?? j['latitude_deg']),
        longitude: _toNullableDouble(j['longitude'] ?? j['lng'] ?? j['long'] ?? j['longitude_deg']),
      );
}
