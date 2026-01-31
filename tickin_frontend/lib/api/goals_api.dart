import '../api/http_client.dart';

class GoalsApi {
  final HttpClient client;
  GoalsApi(this.client);

  /// ✅ Your backend base route
  /// If your backend uses "/api/goals"
  static const String _b = "/api/goals";

  /// ✅ GET /api/goals/monthly?distributorCode=xxx&month=YYYY-MM (optional)
  Future<Map<String, dynamic>> monthly({
    required String distributorCode,
    String? month,
  }) {
    return client.get("$_b/monthly", query: {
      "distributorCode": distributorCode,
      if (month != null) "month": month,
    });
  }
}
