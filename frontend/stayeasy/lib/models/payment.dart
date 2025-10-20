class Payment {
  final int id;
  final int bookingId;
  final String method;
  final String status;
  final double amount;
  final String createdAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.method,
    required this.status,
    required this.amount,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: _toInt(json['id']),
        bookingId: _toInt(json['booking_id'] ?? json['bookingId']),
        method: json['method']?.toString() ?? 'cod',
        status: json['status']?.toString() ?? 'pending',
        amount: _toDouble(json['amount']),
        createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
