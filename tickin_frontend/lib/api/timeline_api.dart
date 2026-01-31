import '../api/http_client.dart';
import '../config/api_config.dart';

class TimelineApi {
  final HttpClient client;
  TimelineApi(this.client);

  String get _b => ApiConfig.timeline;

  /* =========================
     GET TIMELINE (RAW+NEAT)
     GET /timeline/:orderId
  ========================= */
  Future<Map<String, dynamic>> getTimeline(String orderId) {
    return client.get("$_b/$orderId");
  }

  /* =========================
     GET TIMELINE (NEAT ONLY)
     GET /timeline/:orderId/neat
  ========================= */
  Future<Map<String, dynamic>> getTimelineNeat(String orderId) {
    return client.get("$_b/$orderId/neat");
  }

  /* =========================
     LOADING START
  ========================= */
  Future<Map<String, dynamic>> loadingStart(String orderId) {
    return client.post("$_b/loading-start", body: {"orderId": orderId});
  }

  /* =========================
     LOADING ITEM
  ========================= */
  Future<Map<String, dynamic>> loadingItem({
    required String orderId,
    required String productId,
    required int qty,
    String? productName,
  }) {
    return client.post(
      "$_b/loading-item",
      body: {
        "orderId": orderId,
        "productId": productId,
        "qty": qty,
        if (productName != null) "productName": productName,
      },
    );
  }

  /* =========================
     VEHICLE SELECTED
  ========================= */
  Future<Map<String, dynamic>> vehicleSelected({
    required String orderId,
    required String vehicleNo,
  }) {
    return client.post(
      "$_b/vehicle-selected",
      body: {"orderId": orderId, "vehicleNo": vehicleNo},
    );
  }

  /* =========================
     LOADING END
  ========================= */
  Future<Map<String, dynamic>> loadingEnd(String orderId) {
    return client.post("$_b/loading-end", body: {"orderId": orderId});
  }

  /* =========================
     ASSIGN DRIVER
  ========================= */
  Future<Map<String, dynamic>> assignDriver({
    required String orderId,
    required String driverId,
    String? vehicleNo,
  }) {
    return client.post(
      "$_b/assign-driver",
      body: {
        "orderId": orderId,
        "driverId": driverId,
        if (vehicleNo != null) "vehicleNo": vehicleNo,
      },
    );
  }

  /* =========================
     DRIVER STARTED
     (இந்த endpoint backend-ல இல்லைனா remove பண்ணிக்கலாம்)
  ========================= */
  Future<Map<String, dynamic>> driverStarted(String orderId) {
    return client.post("$_b/driver-started", body: {"orderId": orderId});
  }

  /* =========================
     ARRIVED
  ========================= */
  Future<Map<String, dynamic>> arrived({
    required String orderId,
    String stage = "D1",
    String? distributorCode,
  }) {
    return client.post(
      "$_b/arrived",
      body: {
        "orderId": orderId,
        "stage": stage,
        if (distributorCode != null) "distributorCode": distributorCode,
      },
    );
  }

  /* =========================
     UNLOAD START
  ========================= */
  Future<Map<String, dynamic>> unloadStart({
    required String orderId,
    String stage = "D1",
    String? distributorCode,
  }) {
    return client.post(
      "$_b/unload-start",
      body: {
        "orderId": orderId,
        "stage": stage,
        if (distributorCode != null) "distributorCode": distributorCode,
      },
    );
  }

  /* =========================
     UNLOAD END
  ========================= */
  Future<Map<String, dynamic>> unloadEnd({
    required String orderId,
    String stage = "D1",
    String? distributorCode,
  }) {
    return client.post(
      "$_b/unload-end",
      body: {
        "orderId": orderId,
        "stage": stage,
        if (distributorCode != null) "distributorCode": distributorCode,
      },
    );
  }
}
