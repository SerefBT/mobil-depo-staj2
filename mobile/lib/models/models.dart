typedef Json = Map<String, dynamic>;
Json asJson(dynamic value) => Map<String, dynamic>.from(value as Map);
List<Json> asList(dynamic value) => (value as List).map(asJson).toList();

extension JsonFields on Json {
  String s(String key, [String fallback = '']) =>
      this[key]?.toString() ?? fallback;
  int n(String key) => (this[key] as num?)?.toInt() ?? 0;
  bool b(String key) => this[key] == true;
}

class UserProfile {
  final String id, email, fullName, role, unit;
  final int? unitId;
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.unit,
    this.unitId,
  });
  factory UserProfile.fromJson(Json j) => UserProfile(
    id: j.s('id'),
    email: j.s('email'),
    fullName: j.s('fullName'),
    role: j.s('role'),
    unit: j.s('unit'),
    unitId: j['unitId'] as int?,
  );
  bool get isAdmin => role == 'Admin';
  bool get isOperator => role == 'Admin' || role == 'Warehouse';
  String get roleLabel => switch (role) {
    'Admin' => 'Yönetici',
    'Warehouse' => 'Depo personeli',
    _ => 'Birim yetkilisi',
  };
}
