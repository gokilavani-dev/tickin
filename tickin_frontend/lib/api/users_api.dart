// ignore_for_file: avoid_print, unnecessary_type_check
import '../api/http_client.dart';

class UsersApi {
  final HttpClient client;
  UsersApi(this.client);

  /// ✅ Get drivers list as List<Map>
  /// Backend working route: GET /api/users/drivers
  Future<List<Map<String, dynamic>>> getDriversList() async {
    final res = await client.get("/api/users/drivers");

    final list = (res["drivers"] ?? res["data"] ?? res["users"] ?? []) as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// ✅ Get drivers response normalized as { drivers: [...] }
  /// Use this if old code expects Map response
  Future<Map<String, dynamic>> getDrivers() async {
    final res = await client.get("/api/users/drivers");

    // ✅ normalize output
    if (res["drivers"] != null && res["drivers"] is List) return res;

    if (res["data"] != null && res["data"] is List) {
      return {"drivers": res["data"]};
    }

    if (res is Map<String, dynamic> && res.values.any((v) => v is List)) {
      final firstList =
          res.values.firstWhere((v) => v is List, orElse: () => []);
      return {"drivers": firstList};
    }

    return {"drivers": []};
  }

  /// ✅ alias (if old code uses drivers())
  Future<Map<String, dynamic>> drivers() => getDrivers();
}
