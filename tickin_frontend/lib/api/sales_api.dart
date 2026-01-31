import '../api/http_client.dart';
import '../config/api_config.dart';

class SalesApi {
  final HttpClient client;
  SalesApi(this.client);

  Future<Map<String, dynamic>> home() async {
    final url = "${ApiConfig.sales}/home";

    final res = await client.get(url);

    return res;
  }

  Future<List<Map<String, dynamic>>> distributorDropdown() async {
    final res = await home();

    final list = (res["distributorDropdown"] ?? []) as List;

    final result = list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    

    return result;
  }

  Future<List<Map<String, dynamic>>> homeProducts() async {
    final res = await home();
    final list = (res["products"] ?? []) as List;
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}
