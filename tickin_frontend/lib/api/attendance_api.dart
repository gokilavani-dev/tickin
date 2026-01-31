import '../config/api_config.dart';
import 'http_client.dart';

class AttendanceApi {
  final HttpClient client;

  AttendanceApi(this.client);

  // ---------------- CHECK-IN ----------------
  Future<Map<String, dynamic>> checkIn({
    required double lat,
    required double lng,
  }) {
    return client.post(
      "${ApiConfig.attendance}/check-in",
      body: {"lat": lat, "lng": lng},
    );
  }

  // ---------------- CHECK-OUT ----------------
  Future<Map<String, dynamic>> checkOut({
    required double lat,
    required double lng,
  }) {
    return client.post(
      "${ApiConfig.attendance}/check-out",
      body: {"lat": lat, "lng": lng},
    );
  }

  // ---------------- TODAY STATUS (optional) ----------------
  Future<Map<String, dynamic>> todayStatus() {
    return client.get("${ApiConfig.attendance}/today");
  }
}
