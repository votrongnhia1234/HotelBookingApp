class DashboardStats {
  final int users;
  final int hotels;
  final int rooms;
  final int bookings;
  final double revenueAll;
  final double revenueToday;
  final String asOf;

  const DashboardStats({
    required this.users,
    required this.hotels,
    required this.rooms,
    required this.bookings,
    required this.revenueAll,
    required this.revenueToday,
    required this.asOf,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        users: _toInt(json['users']),
        hotels: _toInt(json['hotels']),
        rooms: _toInt(json['rooms']),
        bookings: _toInt(json['bookings']),
        revenueAll: _toDouble(json['revenueAll']),
        revenueToday: _toDouble(json['revenueToday']),
        asOf: json['asOf']?.toString() ?? '',
      );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
