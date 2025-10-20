class Voucher {
  final int id;
  final String code;
  final String title;
  final String description;
  /// 'percent' hoặc 'amount'
  final String discountType;
  /// với percent: 0..100, với amount: số tiền VND
  final int value;
  final int? minOrder;
  final bool onlineOnly;
  final DateTime? expiry;

  Voucher({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.value,
    this.minOrder,
    this.onlineOnly = false,
    this.expiry,
  });

  factory Voucher.fromJson(Map<String, dynamic> j) => Voucher(
    id: (j['id'] ?? 0) is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
    code: (j['code'] ?? '').toString(),
    title: (j['title'] ?? j['name'] ?? '').toString(),
    description: (j['description'] ?? j['desc'] ?? '').toString(),
    discountType: (j['discountType'] ?? j['type'] ?? 'amount').toString(),
    value: (j['value'] ?? 0) is num ? (j['value'] as num).toInt() : int.tryParse('${j['value']}') ?? 0,
    minOrder: j['minOrder'] == null ? null
        : ((j['minOrder'] is num) ? (j['minOrder'] as num).toInt() : int.tryParse('${j['minOrder']}')),
    onlineOnly: (j['onlineOnly'] ?? j['online_only'] ?? false) == true,
    expiry: j['expiry'] == null ? null : DateTime.tryParse('${j['expiry']}'),
  );

  /// Tính mức giảm, có xét minOrder và onlineOnly theo method ('cod' | 'online')
  int discountFor({required int total, required String payMethod}) {
    if (minOrder != null && total < minOrder!) return 0;
    if (onlineOnly && payMethod != 'online') return 0;

    if (discountType == 'percent') {
      final d = (total * value ~/ 100);
      return d;
    }
    return value;
  }
}
