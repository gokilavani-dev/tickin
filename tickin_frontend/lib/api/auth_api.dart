import '../api/http_client.dart';
import '../config/api_config.dart';

class AuthApi {
  final HttpClient client;
  AuthApi(this.client);

  static const String loginPath = "${ApiConfig.auth}/login";

  Future<Map<String, dynamic>> login({
    required String mobile,
    required String password,
  }) async {
    final res = await client.post(
      loginPath,
      body: {
        "mobile": mobile,
        "password": password,
      },
    );

    final token = (res["token"] ?? "").toString();
    if (token.isEmpty) {
      throw Exception("Token not found in login response");
    }

    return res; // { token, user }
  }
}
