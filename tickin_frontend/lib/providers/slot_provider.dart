import 'dart:convert';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/slot_models.dart';

class SlotProvider extends ChangeNotifier {
  final BuildContext context;
  SlotProvider(this.context);

  // state
  bool loading = false;
  bool booking = false;

  String selectedDate = "";
  String companyCode = "";

  /// ✅ grid items (FULL + MERGE flatten)
  List<SlotItem> allSlots = [];

  /// ✅ rules from backend
  SlotRules rules = SlotRules(
    maxAmount: 80000,
    lastSlotEnabled: false,
    lastSlotOpenAfter: "16:30",
  );

  String selectedSession = "Morning";

  // ---------------------------
  // helpers
  // ---------------------------

  String sessionFromTime(String time) {
    final t = SlotItem.normalizeTime(time);
    if (t == "09:00") return "Morning";
    if (t == "12:30") return "Afternoon";
    if (t == "16:00") return "Evening";
    if (t == "20:00") return "Night";
    return "Morning";
  }

  String _today() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _tomorrow() {
    final now = DateTime.now().add(const Duration(days: 1));
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  List<String> allowedDates() => [_today(), _tomorrow()];

  Future<void> initIfNeeded() async {
    if (selectedDate.isEmpty) {
      selectedDate = _today();
      await _loadCompanyCode();
      await loadGrid();
    }
  }

  Future<void> setDate(String d) async {
    selectedDate = d;
    await loadGrid();
  }

  void setSession(String s) {
    selectedSession = s;
    notifyListeners();
  }

  // ---------------------------
  // Company Code from userJson
  // ---------------------------
  Future<void> _loadCompanyCode() async {
    try {
      final scope = TickinAppScope.of(context);
      final userJson = await scope.tokenStore.getUserJson();

      if (userJson != null && userJson.isNotEmpty) {
        final u = jsonDecode(userJson) as Map<String, dynamic>;
        final cid = (u["companyId"] ?? u["companyCode"] ?? "").toString();

        companyCode = cid.contains("#") ? cid.split("#").last : cid;
      }
    } catch (_) {}

    companyCode = companyCode.isEmpty ? "VAGR_IT" : companyCode;
  }

  // ---------------------------
  // Grid load (FIX: flatten nested response)
  // ---------------------------
  Future<void> loadGrid() async {
    loading = true;
    notifyListeners();

    try {
      final scope = TickinAppScope.of(context);
      if (companyCode.isEmpty) await _loadCompanyCode();

      final res = await scope.slotsApi.getGrid(
        companyCode: companyCode,
        date: selectedDate,
      );

      final rawSlots = (res["slots"] ?? []) as List; // ✅ [fullSlots, mergeSlots]
      final rawRules = (res["rules"] ?? {}) as Map;

      final List<Map<String, dynamic>> flattened = [];

      for (final block in rawSlots) {
        if (block is List) {
          for (final item in block) {
            if (item is Map) flattened.add(Map<String, dynamic>.from(item));
          }
        } else if (block is Map) {
          flattened.add(Map<String, dynamic>.from(block));
        }
      }

      final parsed = flattened.map((e) => SlotItem.fromMap(e)).toList();

      /// ✅ unique by sk
      final uniq = <String, SlotItem>{};
      for (final s in parsed) {
        uniq[s.sk] = s;
      }

      allSlots = uniq.values.toList();
      rules = SlotRules.fromMap(Map<String, dynamic>.from(rawRules));
    } catch (_) {
      allSlots = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ---------------------------
  // UI getters
  // ---------------------------

  List<SlotItem> get fullSlots {
    final list = allSlots.where((s) => s.isFull).toList();
    list.sort((a, b) => a.slotIdNum.compareTo(b.slotIdNum));
    return list;
  }

  List<SlotItem> get mergeSlots {
    return allSlots.where((s) => s.isMerge).toList();
  }

  List<SlotItem> get sessionFullSlots {
    final sess = selectedSession;
    final filtered = fullSlots.where((s) => sessionFromTime(s.time) == sess).toList();
    filtered.sort((a, b) => a.slotIdNum.compareTo(b.slotIdNum));
    return filtered;
  }

  List<SlotItem> get sessionMergeSlots {
    final sess = selectedSession;

    final filtered = mergeSlots.where((s) {
      if (sessionFromTime(s.time) != sess) return false;

      // hide completed FULL merge tiles
      if ((s.tripStatus ?? "").toUpperCase() == "FULL") return false;

      if ((s.bookingCount ?? 0) <= 0 && (s.totalAmount ?? 0) <= 0) return false;
      return true;
    }).toList();

    return filtered;
  }

  // ---------------------------
  // BOOK SLOT
  // ---------------------------
  /// ✅ Backend decides FULL/HALF by amount vs threshold
  /// ✅ locationId is important for auto merge (LOC#1..LOC#5)
  Future<bool> bookSlot({
    required SlotItem slot,
    required String distributorCode,
    required String distributorName,
    required String orderId,
    required double amount,
    required String locationId,
  }) async {
    booking = true;
    notifyListeners();

    try {
      final scope = TickinAppScope.of(context);

      await scope.slotsApi.book(
        companyCode: companyCode,
        date: selectedDate,
        time: slot.time,
        pos: slot.pos,
        distributorCode: distributorCode,
        distributorName: distributorName,
        amount: amount,
        orderId: orderId,
        locationId: locationId, // ✅ 반드시 pass பண்ணணும்
      );

      await loadGrid();
      return true;
    } catch (_) {
      return false;
    } finally {
      booking = false;
      notifyListeners();
    }
  }

  // ---------------------------
  // MANAGER confirm merge
  // ---------------------------
  Future<bool> confirmMerge({
    required SlotItem mergeSlot,
    required String managerId,
  }) async {
    try {
      final scope = TickinAppScope.of(context);

      await scope.slotsApi.managerConfirmMerge({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": mergeSlot.time,
        "mergeKey": mergeSlot.mergeKey,
        "managerId": managerId,
      });

      await loadGrid();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------
  // MANAGER manual merge
  // ---------------------------
  Future<bool> manualMerge({
    required SlotItem mergeSlot,
    required List<String> orderIds,
    required String managerId,
  }) async {
    try {
      final scope = TickinAppScope.of(context);

      await scope.slotsApi.managerMergeOrdersManual({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": mergeSlot.time,
        "orderIds": orderIds,
        "targetMergeKey": mergeSlot.mergeKey,
        "managerId": managerId,
      });

      await loadGrid();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------
  // Eligible half bookings (dropdown list)
  // ---------------------------
  Future<List<Map<String, dynamic>>> eligibleHalfBookings(String time) async {
    try {
      final scope = TickinAppScope.of(context);

      final res = await scope.httpClient.get(
        "/api/slots/eligible-half-bookings",
        query: {"date": selectedDate, "time": time},
      );

      final raw = (res["bookings"] ?? []) as List;
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------
  // CANCEL FULL SLOT booking
  // ---------------------------
  Future<bool> cancelFullSlot(SlotItem slot) async {
    try {
      final scope = TickinAppScope.of(context);

      if (slot.pos == null || slot.userId == null) return false;

      await scope.slotsApi.managerCancelBooking({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": slot.time,
        "pos": slot.pos,
        "userId": slot.userId,
        if (slot.orderId != null) "orderId": slot.orderId,
      });

      await loadGrid();
      return true;
    } catch (_) {
      return false;
    }
  }
}
