class User {
  final int id;
  final String name;
  final String email;
  final String phone;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
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

  static String _toStr(dynamic v) => v?.toString() ?? '';

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: _toInt(j['id'] ?? j['user_id']),
    name: _toStr(j['name'] ?? j['fullName'] ?? j['username']),
    email: _toStr(j['email']),
    phone: _toStr(j['phone'] ?? j['phoneNumber']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
  };
}
