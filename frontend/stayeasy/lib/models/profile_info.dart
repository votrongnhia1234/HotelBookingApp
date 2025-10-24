class ProfileInfo {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? address;

  ProfileInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.address,
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
        final asDouble = double.tryParse(v);
        if (asDouble != null) return asDouble.toInt();
      }
      return 0;
    }

    String toStr(dynamic v) => v?.toString() ?? '';

    return ProfileInfo(
      id: toInt(json['id']),
      name: toStr(json['name']),
      email: toStr(json['email']),
      phone: toStr(json['phone']),
      role: toStr(json['role']),
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'address': address,
      };

  ProfileInfo copyWith({
    String? name,
    String? phone,
    String? address,
  }) =>
      ProfileInfo(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        role: role,
        address: address ?? this.address,
      );
}
