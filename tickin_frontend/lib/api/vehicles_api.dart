import '../api/http_client.dart';
import '../config/api_config.dart';

class VehiclesApi {
  final HttpClient client;
  VehiclesApi(this.client);

  /// GET /vehicles/available
  Future<List<String>> getAvailable() async {
    final res = await client.get("${ApiConfig.vehicles}/available");

    final vehicles = res["vehicles"];

    if (vehicles is List) {
      return vehicles.map((e) => e.toString()).toList();
    }

    return [];
  }

  /// ✅ BACKWARD COMPAT: Manager screen expects getVehicles()
  Future<Map<String, dynamic>> getVehicles() async {
    final list = await getAvailable();
    return {"vehicles": list};
  }
}
