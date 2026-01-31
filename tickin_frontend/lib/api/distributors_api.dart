import '../api/http_client.dart';
import '../config/api_config.dart';

class DistributorsApi {
  final HttpClient client;
  DistributorsApi(this.client);

  Future<Map<String, dynamic>> getByCode(String code) {
    return client.get("${ApiConfig.distributors}/$code");
  }
}
