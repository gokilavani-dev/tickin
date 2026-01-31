// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import '../api/http_client.dart';
import '../config/api_config.dart';
import '../../models/half_booking_model.dart';
class SlotsApi {
  final HttpClient client;
  SlotsApi(this.client);

  Future<Map<String, dynamic>> getGrid({
    required String companyCode,
    required String date,
  }) {
    return client.get(ApiConfig.slots, query: {
      "companyCode": companyCode,
      "date": date,
    });
  }

  Future<Map<String, dynamic>> book({
    required String companyCode,
    required String date,
    required String time,
    String? pos,
    required String distributorCode,
    required double amount,
    required String orderId,
    String? userId,
    double? lat,
    double? lng,
    String? distributorName,
    String? locationId,
  }) {
    // ✅ FORCE string trim (avoid null/empty confusion)
    String loc = (locationId ?? "").toString().trim();
loc = loc.replaceAll(RegExp(r'^(LOC#)+', caseSensitive: false), '');


    return client.post("${ApiConfig.slots}/book", body: {
      "companyCode": companyCode,
      "date": date,
      "time": time,
      if (pos != null) "pos": pos,
      "distributorCode": distributorCode,
      if (distributorName != null) "distributorName": distributorName,
      "amount": amount,
      "orderId": orderId,
      if (userId != null) "userId": userId,
      if (lat != null) "lat": lat,
      if (lng != null) "lng": lng,

      // ✅ IMPORTANT: send only when not empty
      if (loc.isNotEmpty) "locationId": loc,
    });
  }
Future<List<Map<String, dynamic>>> getHalfBookingsRaw({
  required String date,
  required String mergeKey,
  required String time,
}) async {
  final res = await client.get(
    "${ApiConfig.slots}/manager/half-bookings",
    query: {
      "date": date,
      "mergeKey": mergeKey,
      "time": time,
    },
  );

  final list = (res["bookings"] ?? []) as List;
  return list.map((e) => Map<String, dynamic>.from(e)).toList();
}
Future<dynamic> managerCancelBooking(Map<String, dynamic> body) async {
  return client.post(
    "${ApiConfig.slots}/manager/cancel-booking",
    body: body,
  );
}

  Future<Map<String, dynamic>> managerDisableSlot(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/disable-slot", body: body);

Future<Map<String, dynamic>> halfMergeConfirm(
    Map<String, dynamic> body,) async {
  return client.post(
    "${ApiConfig.slots}/half-merge/confirm",
    body: body,
  );
}

  Future<Map<String, dynamic>> managerEnableSlot(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/enable-slot", body: body);

  Future<Map<String, dynamic>> managerConfirmMerge(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/merge/confirm", body: body);

  Future<Map<String, dynamic>> cancelHalfMerge(Map<String, dynamic> body) =>
    client.post("${ApiConfig.slots}/half-merge/cancel", body: body);

Future<Map<String, dynamic>> confirmHalfMerge(Map<String, dynamic> body) =>
    client.post("${ApiConfig.slots}/half-merge/confirm", body: body);
    
  Future<Map<String, dynamic>> managerMoveMerge(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/merge/move", body: body);

Future<Map<String, dynamic>> managerConfirmDayMerge(
  Map<String, dynamic> body,
) =>
    client.post("${ApiConfig.slots}/merge/confirm-day", body: body);

  Future<Map<String, dynamic>> managerEditTime(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/edit-time", body: body);

  Future<Map<String, dynamic>> managerSetSlotMax(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/set-max", body: body);

  Future<Map<String, dynamic>> managerSetGlobalMax(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/set-global-max", body: body);

  Future<Map<String, dynamic>> toggleLastSlot(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/last-slot/toggle", body: body);

  /// ✅ FIX: correct manual merge endpoint (remove /manual)
  /// Backend usually expects: POST /api/slots/merge/orders
  Future<Map<String, dynamic>> managerMergeOrdersManual(Map<String, dynamic> body) =>
    client.post("${ApiConfig.slots}/merge/orders/manual", body: body);

  Future<Map<String, dynamic>> cancelConfirmedMerge(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/merge/cancel-confirmed", body: body);

  Future<Map<String, dynamic>> waitingHalfByDate({
  required String date,
}) {
  return client.get("${ApiConfig.slots}/waiting-half-by-date", query: {
    "date": date,
  });
}
      
Future<Map<String, dynamic>> availableFullTimes({required String date}) {
  return client.get("${ApiConfig.slots}/available-full-times", query: {
    "date": date,
  });
}

Future<Map<String, dynamic>> managerManualMergePickTime(Map<String, dynamic> body) {
  return client.post("${ApiConfig.slots}/merge/manual-pick-time", body: body);
}
String _normalizeMergeKey(String mk) {
  var s = mk.toString().trim();

  // remove KEY# prefix if accidentally passed
  if (s.toUpperCase().startsWith("KEY#")) {
    s = s.substring(4);
  }

  // if plain number like "4" -> make LOC#4
  if (RegExp(r'^\d+$').hasMatch(s)) {
    s = "LOC#$s";
  }

  return s;
}

Future<List<HalfBooking>> getHalfBookings({
  required String date,
  required String mergeKey,
  required String time,
}) async {
  final mk = _normalizeMergeKey(mergeKey);

  final res = await client.get(
    "${ApiConfig.slots}/manager/half-bookings",
    query: {
      'date': date,
      'mergeKey': mk,
      'time': time,
    },
  );

  final list = (res['bookings'] as List?) ?? [];
  return list.map((e) => HalfBooking.fromJson(e)).toList();
}
}
