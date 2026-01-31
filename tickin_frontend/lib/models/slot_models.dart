// ignore_for_file: curly_braces_in_flow_control_structures, unused_local_variable, unnecessary_null_in_if_null_operators
import '../screens/slots/slot_generator.dart';

class SlotRules {
  final double maxAmount;
  final bool lastSlotEnabled;
  final String lastSlotOpenAfter;

  SlotRules({
    required this.maxAmount,
    required this.lastSlotEnabled,
    required this.lastSlotOpenAfter,
  });

  factory SlotRules.fromMap(Map<String, dynamic> m) {
    final raw = m["maxAmount"] ?? m["threshold"] ?? 80000;

    return SlotRules(
      maxAmount: (raw is num) ? raw.toDouble() : double.tryParse("$raw") ?? 80000,
      lastSlotEnabled: m["lastSlotEnabled"] == true,
      lastSlotOpenAfter: m["lastSlotOpenAfter"]?.toString() ?? "16:30",
    );
  }
}

class SlotItem {
  final String pk;
  final String sk;

  final String time;
  final String vehicleType; // FULL / HALF
  final String? pos;
  final String status;

  final String? orderId;

  final String? mergeKey;
  final double? totalAmount;
  final double? amount;
  final String? tripStatus;

  final double? lat;
  final double? lng;

  final bool blink;
  final String? userId;

  final String? distributorName;
  final String? distributorCode;
  final String? bookedBy;

  final String? locationId;
  final String? companyCode;
  final String? date;

  final List<Map<String, dynamic>> participants;
  final double? distanceKm;
  final int? bookingCount;

  SlotItem({
    required this.pk,
    required this.sk,
    required this.time,
    required this.vehicleType,
    required this.status,
    this.pos,
    this.locationId,
    this.orderId,
    this.amount,
    this.mergeKey,
    this.totalAmount,
    this.tripStatus,
    this.lat,
    this.lng,
    this.blink = false,
    this.userId,
    this.distributorName,
    this.distributorCode,
    this.bookedBy,
    this.companyCode,
    this.date,
    this.participants = const [],
    this.distanceKm,
    this.bookingCount,
  });

  // ------------------------
  // ✅ BASIC GETTERS
  // ------------------------
  bool get isFull => vehicleType.toUpperCase() == "FULL";
  bool get isMerge => sk.startsWith("MERGE_SLOT#");

  String get displayTime {
    if (isMerge) return "";
    return normalizeTime(time);
  }

  // ------------------------
  // ✅ HELPERS
  // ------------------------
  static String normalizeTime(String t) {
    final x = t.trim();
    if (!x.contains(":")) return x;

    final parts = x.split(":");
    final hh = parts[0].padLeft(2, "0");
    final mm = (parts.length > 1 ? parts[1] : "00").padLeft(2, "0");
    return "$hh:$mm";
  }

  static String? _cleanMergeKey(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;

    final up = s.toUpperCase();
    if (up.contains("NAN") || up.endsWith("#NULL") || up == "NULL") return null;
    return s;
  }

  static String? _cleanStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == "null" || s.toUpperCase() == "NAN") {
      return null;
    }
    return s;
  }

  // ------------------------
  // ✅ FROM MAP
  // ------------------------
  factory SlotItem.fromMap(Map<String, dynamic> m) {
    final pk = m["pk"]?.toString() ?? "";
    final sk = m["sk"]?.toString() ?? "";

    String? companyCode;
    String? date;
    try {
      final parts = pk.split("#");
      final cIdx = parts.indexOf("COMPANY");
      final dIdx = parts.indexOf("DATE");
      if (cIdx != -1 && cIdx + 1 < parts.length) companyCode = parts[cIdx + 1];
      if (dIdx != -1 && dIdx + 1 < parts.length) date = parts[dIdx + 1];
    } catch (_) {}

    final rawLat = m["lat"];
    final rawLng = m["lng"];

    final rawTime =
        (m["time"] ?? m["slotTime"] ?? m["slot_time"])?.toString() ?? "";
    var parsedTime = normalizeTime(rawTime);

    if ((parsedTime.isEmpty || parsedTime == "00:00") &&
        sk.startsWith("MERGE_SLOT#")) {
      try {
        final parts = sk.split("#");
        if (parts.length > 1) parsedTime = normalizeTime(parts[1]);
      } catch (_) {}
    }

    final rawStatus = (m["status"] ?? "AVAILABLE").toString();

    final participants = <Map<String, dynamic>>[];
    if (m["participants"] is List) {
      for (final p in m["participants"]) {
        if (p is Map) participants.add(Map<String, dynamic>.from(p));
      }
    }

    double? totalAmount;
    if (m["totalAmount"] is num) {
      totalAmount = (m["totalAmount"] as num).toDouble();
    }

    double? amount;
    if (m["amount"] is num) {
      amount = (m["amount"] as num).toDouble();
    }

    final vt = (m["vehicleType"] ?? "FULL").toString().toUpperCase();
    final finalVehicleType = vt == "HALF" ? "HALF" : "FULL";

    final cleanedMergeKey = _cleanMergeKey(m["mergeKey"]);
    final locId = _cleanStr(m["locationId"]);
String? mergeKeyFromSk;
if (sk.startsWith("MERGE_SLOT#")) {
  final parts = sk.split("#");
  if (parts.length >= 3) {
    mergeKeyFromSk = parts.sublist(2).join("#").trim();
    // ✅ IMPORTANT: ignore LOC# mergeKeys
    if (mergeKeyFromSk.toUpperCase().startsWith("LOC#")) {
      mergeKeyFromSk = null;
    }
  }
}
final safeCleanedMergeKey =
    (cleanedMergeKey != null && cleanedMergeKey.toUpperCase().startsWith("LOC#"))
        ? null
        : cleanedMergeKey;

final finalMergeKey = safeCleanedMergeKey ?? mergeKeyFromSk;

    return SlotItem(
      pk: pk,
      sk: sk,
      time: parsedTime,
      vehicleType: finalVehicleType,
      pos: _cleanStr(m["pos"]),
      status: rawStatus,
      orderId: _cleanStr(m["orderId"]),
      mergeKey: finalMergeKey,
      totalAmount: totalAmount,
      amount: amount,
      tripStatus: _cleanStr(m["tripStatus"]) ?? "PARTIAL",
      lat: (rawLat is num) ? rawLat.toDouble() : double.tryParse("$rawLat"),
      lng: (rawLng is num) ? rawLng.toDouble() : double.tryParse("$rawLng"),
      blink: m["blink"] == true,
      userId: _cleanStr(m["userId"]),
      distributorName: _cleanStr(m["distributorName"]),
      distributorCode: _cleanStr(m["distributorCode"]),
      bookedBy: _cleanStr(m["bookedBy"]),
      locationId: locId,
      companyCode: companyCode,
      date: date,
      participants: participants,
      distanceKm: (m["distanceKm"] is num)
          ? (m["distanceKm"] as num).toDouble()
          : double.tryParse("${m["distanceKm"]}"),
      bookingCount: (m["bookingCount"] is num)
          ? (m["bookingCount"] as num).toInt()
          : int.tryParse("${m["bookingCount"]}"),
    );
  }

  // ------------------------
  // ✅ STATUS HELPERS
  // ------------------------
  String get normalizedStatus {
    final s = status.toUpperCase();
    if (s == "CONFIRMED") return "BOOKED";
    return s;
  }

  bool get isBooked => normalizedStatus == "BOOKED";
  bool get isAvailable => normalizedStatus == "AVAILABLE";

  String get sessionLabel {
    if (isMerge) return "";
    final t = normalizeTime(time);

    for (final e in sessionTimes.entries) {
      if (e.value.contains(t)) return e.key;
    }

    final h = int.tryParse(t.split(":")[0]) ?? 0;
    if (h >= 9 && h < 12) return "Morning";
    if (h >= 12 && h < 15) return "Afternoon";
    if (h >= 15 && h < 18) return "Evening";
    return "Night";
  }

  int get slotIdNum {
    int base;
    switch (sessionLabel) {
      case "Morning":
        base = 3000;
        break;
      case "Afternoon":
        base = 3010;
        break;
      case "Evening":
        base = 3020;
        break;
      case "Night":
        base = 3030;
        break;
      default:
        base = 3000;
    }

    int posOffset = 0;
    final p = (pos ?? "A").toUpperCase();
    if (p == "B") posOffset = 1;
    else if (p == "C") posOffset = 2;
    else if (p == "D") posOffset = 3;

    return base + posOffset;
  }

  String get slotIdLabel => slotIdNum.toString();
}

// ------------------------
// ✅ COPY WITH EXTENSION
// ------------------------
extension SlotItemCopy on SlotItem {
  SlotItem copyWith({
    List<Map<String, dynamic>>? participants,
    int? bookingCount,
    double? totalAmount,
    String? tripStatus,
  }) {
    return SlotItem(
      pk: pk,
      sk: sk,
      time: time,
      vehicleType: vehicleType,
      status: status,
      pos: pos,
      orderId: orderId,
      mergeKey: mergeKey,
      amount: amount,
      tripStatus: tripStatus ?? this.tripStatus,
      lat: lat,
      lng: lng,
      blink: blink,
      userId: userId,
      distributorName: distributorName,
      distributorCode: distributorCode,
      bookedBy: bookedBy,
      locationId: locationId,
      companyCode: companyCode,
      date: date,
      participants: participants ?? this.participants,
      bookingCount: bookingCount ?? this.bookingCount,
      totalAmount: totalAmount ?? this.totalAmount,
      distanceKm: distanceKm,
    );
  }
}
