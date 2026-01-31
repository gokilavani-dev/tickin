import '../config/api_config.dart';
import 'http_client.dart';

class AttendanceConfigApi {
  final HttpClient client;

  AttendanceConfigApi(this.client);

  // ---------------- GET CONFIG ----------------
  Future<Map<String, dynamic>> getConfig() {
    return client.get("${ApiConfig.attendance}/config/allowance");
  }

  // ---------------- UPDATE CONFIG ----------------
  Future<Map<String, dynamic>> updateConfig({
    required int managerLoadmanBata,
    required int driverMorningBata,
    required int driverNightAllowance,
    required Map<String, String> managerLoadmanCheckin,
    required Map<String, String> driverCheckinNormal,
    required Map<String, String> driverCheckinAfterNightDuty,
  }) {
    return client.post(
      "${ApiConfig.attendance}/config/allowance",
      body: {
        "managerLoadmanBata": managerLoadmanBata,
        "driverMorningBata": driverMorningBata,
        "driverNightAllowance": driverNightAllowance,
        "managerLoadmanCheckin": managerLoadmanCheckin,
        "driverCheckinNormal": driverCheckinNormal,
        "driverCheckinAfterNightDuty": driverCheckinAfterNightDuty,
      },
    );
  }
}
