class BookingSummary {
  final int total;
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final double valuePipeline;
  final double valueCompleted;

  const BookingSummary({
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.valuePipeline,
    required this.valueCompleted,
  });

  factory BookingSummary.fromJson(Map<String, dynamic> json) => BookingSummary(
        total: _toInt(json['total']),
        pending: _toInt(json['pending']),
        confirmed: _toInt(json['confirmed']),
        completed: _toInt(json['completed']),
        cancelled: _toInt(json['cancelled']),
        valuePipeline: _toDouble(json['valuePipeline']),
        valueCompleted: _toDouble(json['valueCompleted']),
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
