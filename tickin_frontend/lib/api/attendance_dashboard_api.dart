import '../config/api_config.dart';
import 'http_client.dart';

class AttendanceDashboardApi {
  final HttpClient client;

  AttendanceDashboardApi(this.client);

  // ---------------- WEEKLY SUMMARY ----------------
  Future<Map<String, dynamic>> weeklySummary() {
    return client.get("${ApiConfig.attendance}/dashboard/weekly-summary");
  }

  // ---------------- TODAY ATTENDANCE ----------------
  Future<Map<String, dynamic>> todayAttendance() {
    return client.get("${ApiConfig.attendance}/dashboard/today");
  }

  // ---------------- DAY-WISE ATTENDANCE ----------------
  Future<Map<String, dynamic>> attendanceByDate({required String date}) {
    return client.get(
      "${ApiConfig.attendance}/dashboard/by-date",
      query: {"date": date},
    );
  }

  // ---------------- MONTHLY SUMMARY ----------------
  Future<Map<String, dynamic>> monthlySummary({required String month}) {
    return client.get(
      "${ApiConfig.attendance}/dashboard/monthly-summary",
      query: {"month": month},
    );
  }
}
