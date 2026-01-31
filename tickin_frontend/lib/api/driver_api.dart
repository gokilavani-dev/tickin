import '../api/http_client.dart';
import '../config/api_config.dart';
class DriverApi {
  final HttpClient client;
  DriverApi(this.client);

/// 🚚 Driver active orders (card list)
  Future<List<Map<String, dynamic>>> getDriverOrders(String driverId) async {
    final res = await client.get("${ApiConfig.driver}/$driverId/orders");
    final list = (res["orders"] ?? res["data"] ?? []) as List;
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  /// 🔁 Update driver order status (MATCHES BACKEND)
  Future<Map<String, dynamic>> updateStatus({
    required String orderId,
    required String nextStatus,
    double? lat,
    double? lng,
    bool force = false,
  }) {
    return client.post(
      "${ApiConfig.driver}/order/$orderId/status",
      body: {
        "nextStatus": nextStatus, // ✅ IMPORTANT
        if (lat != null) "currentLat": lat,
        if (lng != null) "currentLng": lng,
        "force": force,
      },
    );
  }

  /// 📍 Optional: validate reach (if you want separate check)
  Future<Map<String, dynamic>> validateReach({
    required String orderId,
    required double lat,
    required double lng,
  }) {
    return client.post(
      "${ApiConfig.driver}/order/$orderId/validate-reach",
      body: {"currentLat": lat, "currentLng": lng},
    );
  }
}
