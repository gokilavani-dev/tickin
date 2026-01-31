// ignore_for_file: deprecated_member_use, unused_import, avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import 'order_details_screen.dart';
import 'slots/slot_booking_screen.dart';
import 'order_unified_tracking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool loading = false;
  bool _loadedOnce = false;

  List<Map<String, dynamic>> orders = [];

  String role = "";
  String selectedStatus = "CONFIRMED";
  String selectedDate = DateFormat("yyyy-MM-dd").format(DateTime.now());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _initAndLoad();
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(selectedDate),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 30)),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = DateFormat("yyyy-MM-dd").format(picked);
    });

    await _load();
  }

  bool get isManager => role.contains("MANAGER") || role.contains("MASTER");
  bool get isSalesOfficerVnr =>
      role.toUpperCase().trim() == "SALES_OFFICER_VNR" ||
      role.toUpperCase().trim() == "SALES OFFICER VNR";

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _initAndLoad() async {
    try {
      final scope = TickinAppScope.of(context);
      final userJson = await scope.tokenStore.getUserJson();
      if (userJson != null && userJson.isNotEmpty) {
        final u = jsonDecode(userJson);
        role = (u["role"] ?? u["userRole"] ?? "").toString().toUpperCase();
      }
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      final res = isManager
          ? await scope.ordersApi.all(status: selectedStatus)
          : await scope.ordersApi.my();

      dynamic raw = res["orders"] ?? res["items"] ?? res["data"] ?? res;
      if (raw is Map) raw = raw["orders"] ?? raw["items"] ?? raw["data"] ?? [];

      setState(() {
        orders = (raw is List ? raw : [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      toast("❌ Load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _safe(Map o, List<String> keys) {
    for (final k in keys) {
      final v = o[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return "-";
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  //dublicates
  bool _isSlotBooked(Map<String, dynamic> o) {
    // 1) slotBooked flag
    final v = o["slotBooked"];
    final slotBooked =
        (v is bool && v == true) ||
        (v is num && v == 1) ||
        (v ?? "").toString().trim().toLowerCase() == "true" ||
        (v ?? "").toString().trim() == "1";

    // 2) slotId presence (HALF also has slotId)
    final slotId = (o["slotId"] ?? "").toString().trim();

    // 3) mergedIntoOrderId presence (merged half orders)
    final mergedInto = (o["mergedIntoOrderId"] ?? "").toString().trim();

    // ✅ final decision
    if (slotBooked) return true;
    if (slotId.isNotEmpty) return true;
    if (mergedInto.isNotEmpty) return true;

    return false;
  }

  /// ✅ Normalize to LOC# format (auto merge compatibility)
  String _normalizeRawLocId(Map<String, dynamic> o) {
    String raw = (o["locationId"] ?? "").toString().trim();
    String mergeKey = (o["mergeKey"] ?? "").toString().trim();

    if (raw.toUpperCase().startsWith("LOC#")) raw = raw.substring(4);
    if (raw.toUpperCase().startsWith("LOC#LOC#")) {
      raw = raw.replaceFirst("LOC#LOC#", "");
    }

    if (raw.isEmpty && mergeKey.toUpperCase().startsWith("LOC#")) {
      raw = mergeKey.substring(4);
    }
    if (raw.toUpperCase().startsWith("LOC#LOC#")) {
      raw = raw.replaceFirst("LOC#LOC#", "");
    }
    return raw;
  }

  Future<void> _openSlotBooking(Map<String, dynamic> o) async {
    final orderId = _safe(o, ["orderId", "id"]);
    final distCode = _safe(o, ["distributorId", "distributorCode"]);
    final distName = _safe(o, ["distributorName", "agencyName"]);
    final amount = _num(
      o["amount"] ?? o["totalAmount"] ?? o["grandTotal"],
    ).toDouble();

    final locationId = _normalizeRawLocId(o);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SlotBookingScreen(
          role: role,
          distributorCode: distCode,
          distributorName: distName,
          orderId: orderId,
          amount: amount,
          locationId: locationId.isEmpty ? null : locationId,
        ),
      ),
    );

    await _load();
  }

  Future<void> _deleteOrder(Map<String, dynamic> o) async {
    final orderId = _safe(o, ["orderId", "id"]);
    if (orderId.isEmpty || orderId == "-") {
      toast("❌ OrderId missing");
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Order?"),
        content: Text("Delete $orderId ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final scope = TickinAppScope.of(context);
      await scope.ordersApi.deleteOrder(orderId);
      toast("✅ Order deleted");
      await _load();
    } catch (e) {
      toast("❌ Delete failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isManager ? "All Orders" : "My Orders"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];

                final orderId = _safe(o, ["orderId", "id"]);
                final dist = _safe(o, [
                  "distributorName",
                  "agencyName",
                  "distributorId",
                ]);
                final amount = _num(
                  o["amount"] ?? o["totalAmount"] ?? o["grandTotal"],
                );
                final slotBooked = _isSlotBooked(o);
                print(
                  "ORDER=$orderId slotBooked=${o["slotBooked"]} slotId=${o["slotId"]} "
                  "slotDate=${o["slotDate"]} slotTime=${o["slotTime"]} slotPos=${o["slotPos"]} "
                  "mergeKey=${o["mergeKey"]} bookingSk=${o["bookingSk"]} mergedIntoOrderId=${o["mergedIntoOrderId"]}",
                );
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(dist),
                    subtitle: Text("Order: $orderId"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "₹${amount.toStringAsFixed(0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),

                        /// ✅ SLOT always visible but disabled if booked
                        /// ✅ SLOT hidden for SALES_OFFICER_VNR
                        if (!isSalesOfficerVnr) ...[
                          ElevatedButton(
                            onPressed: slotBooked
                                ? null
                                : () => _openSlotBooking(o),
                            child: const Text("SLOT"),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderUnifiedTrackingScreen(
                                  orderId: orderId,
                                ),
                              ),
                            );
                          },
                          child: const Text("TRACK"),
                        ),

                        /// ✅ DELETE always visible but disabled if booked
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: slotBooked ? Colors.grey : Colors.red,
                          ),
                          onPressed: slotBooked ? null : () => _deleteOrder(o),
                        ),
                      ],
                    ),
                    onTap: () {
                      // ✅ SALES_OFFICER_VNR -> Order Details
                      if (isSalesOfficerVnr) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailsScreen(orderId: orderId),
                          ),
                        );
                        return;
                      }

                      // existing behavior for others
                      if (slotBooked) {
                        toast("✅ Slot already booked. SLOT & DELETE disabled.");
                        return;
                      }
                      _openSlotBooking(o);
                    },

                    onLongPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailsScreen(orderId: orderId),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
