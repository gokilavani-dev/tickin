import 'dart:convert';

class AppUser {
  final String? userId;
  final String? username;
  final String? role; // MANAGER / SALES_OFFICER / DISTRIBUTOR
  final String? distributorCode;

  AppUser({
    this.userId,
    this.username,
    this.role,
    this.distributorCode,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) {
    return AppUser(
      userId: m["userId"]?.toString(),
      username: m["username"]?.toString(),
      role: m["role"]?.toString(),
      distributorCode: m["distributorCode"]?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        "userId": userId,
        "username": username,
        "role": role,
        "distributorCode": distributorCode,
      };

  String toJsonString() => jsonEncode(toMap());

  static AppUser? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    final m = jsonDecode(s);
    if (m is Map<String, dynamic>) return AppUser.fromMap(m);
    return null;
  }

  /// 🔐 Role helpers
  bool get isManager => role == "MANAGER";
  bool get isSalesOfficer => role == "SALES_OFFICER";
  bool get isDistributor => role == "DISTRIBUTOR";
}
