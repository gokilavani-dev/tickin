// ignore_for_file: deprecated_member_use, unused_import, prefer_iterable_wheretype, unused_local_variable, unused_element, avoid_print

import 'package:flutter/material.dart';
import '../app_scope.dart';
import 'order_details_screen.dart';
import 'slots/slot_booking_screen.dart';

class ManagerAllOrdersScreen extends StatefulWidget {
  const ManagerAllOrdersScreen({super.key});

  @override
  State<ManagerAllOrdersScreen> createState() => _ManagerAllOrdersScreenState();
}

class _ManagerAllOrdersScreenState extends State<ManagerAllOrdersScreen> {
  bool loading = false;
  List<Map<String, dynamic>> orders = [];
  String selectedStatus = "CONFIRMED";
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _load();
    }
  }

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final res = await scope.ordersApi.all(status: selectedStatus);

      dynamic raw = res["orders"] ?? res["items"] ?? res["data"] ?? res;
      if (raw is Map) raw = raw["orders"] ?? raw["items"] ?? raw["data"] ?? [];

      final list = raw is List ? raw : [];
      setState(() {
        orders = list
            .where((e) => e is Map)
            .map((e) => Map<String, dynamic>.from(e as Map))
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
      if (o[k] != null && o[k].toString().isNotEmpty) return o[k].toString();
    }
    return "-";
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  /// ✅ handles bool / "true" / 1 etc
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
// ✅ IMPORTANT: always returns raw locationId (ex: "1","2","3","4","5")
String _normalizeRawLocId(Map<String, dynamic> o) {
  String raw = (o["locationId"] ?? o["mergeKey"] ?? "").toString().trim();

  // remove "LOC#" prefix if already stored as LOC#...
  if (raw.toUpperCase().startsWith("LOC#")) {
    raw = raw.substring(4);
  }

  // sometimes your DB has LOC#LOC#GEO... remove extra LOC#
  while (raw.toUpperCase().startsWith("LOC#")) {
    raw = raw.substring(4);
  }

  return raw.trim();
}
  /// ✅ Slot booking open
 Future<void> _openSlotBooking(Map<String, dynamic> o) async {
  final orderId = _safe(o, ["orderId", "id"]);
  final amount = _num(o["amount"] ?? o["totalAmount"] ?? o["grandTotal"]).toDouble();

  final distCode = (o["distributorId"] ?? o["distributorCode"] ?? "").toString();
  final distName = (o["distributorName"] ?? o["agencyName"] ?? "").toString();

  final rawLoc = _normalizeRawLocId(o);

  print("✅ ORDER OPEN => orderId=$orderId locationId=$rawLoc");

  if (orderId.isEmpty || orderId == "-") {
    toast("❌ OrderId missing");
    return;
  }
  if (distCode.isEmpty || distName.isEmpty) {
    toast("❌ Distributor details missing");
    return;
  }

  final ok = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SlotBookingScreen(
        role: "MANAGER",
        distributorCode: distCode,
        distributorName: distName,
        orderId: orderId,
        amount: amount,

        // ✅ MUST PASS RAW locationId
        locationId: rawLoc.isEmpty ? null : rawLoc,
      ),
    ),
  );

  if (ok == true) await _load();
}
Future<void> _cancelBookedSlot(Map<String, dynamic> o) async {
  final scope = TickinAppScope.of(context);

  final orderId = _safe(o, ["orderId", "id"]);
  if (orderId.isEmpty || orderId == "-") {
    toast("❌ OrderId missing");
    return;
  }

  // ✅ these keys must come from backend orders list (important!)
final companyCode = (o["ompanyCode"] ?? "").toString().trim();
final slotDate = (o["slotDate"] ?? "").toString().trim();
final slotTime = (o["slotTime"] ?? "").toString().trim();
final slotPos  = (o["slotPos"] ?? o["pos"] ?? "").toString().trim();
final bookedBy = (o["bookedBy"] ?? o["userId"] ?? "").toString().trim();
  // HALF cancel keys (if available)
final bookingSk = (o["bookingSk"] ?? "").toString().trim();
final mergeKey  = (o["mergeKey"] ?? "").toString().trim();
if (slotDate.isEmpty || slotTime.isEmpty) {
    toast("❌ slotDate / slotTime missing in order payload");
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Cancel Slot Booking?"),
      content: Text("Order: $orderId\nCancel slot and rebook again?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("No"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Yes Cancel"),
        ),
      ],
    ),
  );

  if (ok != true) return;

  try {
    // ✅ FULL cancel payload
    if (slotPos.isNotEmpty && bookedBy.isNotEmpty) {
      await scope.slotsApi.managerCancelBooking({
        "companyCode": companyCode, 
        "date": slotDate,
        "time": slotTime,
        "pos": slotPos,
        "userId": bookedBy,
        "orderId": orderId,
      });
    }
    // ✅ HALF cancel payload (needs bookingSk + mergeKey)
    else if (bookingSk.isNotEmpty && mergeKey.isNotEmpty) {
      await scope.slotsApi.managerCancelBooking({
        "companyCode": companyCode,
        "date": slotDate,
        "time": slotTime,
        "bookingSk": bookingSk,
        "mergeKey": mergeKey,
        "orderId": orderId,
      });
    } else {
      toast("❌ Cancel failed: missing pos/userId OR bookingSk/mergeKey");
      return;
    }

    toast("✅ Slot cancelled. Now rebook.");
    await _load();
  } catch (e) {
    toast("❌ Cancel failed: $e");
  }
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
              child: const Text("No")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes Delete")),
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
        title: const Text("All Orders (Manager)"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: "Status Filter",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "CONFIRMED", child: Text("CONFIRMED")),
                DropdownMenuItem(value: "PENDING", child: Text("PENDING")),
                DropdownMenuItem(value: "DRAFT", child: Text("DRAFT")),
                DropdownMenuItem(value: "CANCELLED", child: Text("CANCELLED")),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => selectedStatus = v);
                await _load();
              },
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                    ? const Center(child: Text("No orders found"))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: orders.length,
                          itemBuilder: (_, i) {
                            final o = orders[i];

                            final orderId = _safe(o, ["orderId", "id"]);
                            final status = _safe(o, ["status"]);
                            final dist = _safe(o, [
                              "distributorName",
                              "agencyName",
                              "distributorId"
                            ]);

                            final amount = _num(
                              o["amount"] ?? o["totalAmount"] ?? o["grandTotal"],
                            ).toDouble();

                            final createdAt =
                                _safe(o, ["createdAt", "created_at", "date"]);

                            final slotBooked = _isSlotBooked(o);
print("ORDER=$orderId slotBooked=${o["slotBooked"]} slotId=${o["slotId"]} "
      "slotDate=${o["slotDate"]} slotTime=${o["slotTime"]} slotPos=${o["slotPos"]} "
      "mergeKey=${o["mergeKey"]} bookingSk=${o["bookingSk"]} mergedIntoOrderId=${o["mergedIntoOrderId"]}");
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                title: Text(dist),
                                subtitle: Text(
                                  "Order: $orderId\nStatus: $status\nDate: $createdAt",
                                ),
                               trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      "₹${amount.toStringAsFixed(0)}",
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    const SizedBox(width: 10),
if (!slotBooked) ...[
  ElevatedButton(
    onPressed: () => _openSlotBooking(o),
    child: const Text("SLOT"),
  ),
  const SizedBox(width: 6),
  IconButton(
    icon: const Icon(Icons.delete, color: Colors.red),
    onPressed: () => _deleteOrder(o),
  ),
] else ...[
  IconButton(
    icon: const Icon(Icons.cancel, color: Colors.orange),
    onPressed: () => _cancelBookedSlot(o),
  ),
  const SizedBox(width: 6),
  ElevatedButton(
    onPressed: null,
    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
    child: const Text("SLOT"),
  ),
]
  ],
),
                                onTap: () {
                                  if (!slotBooked) {
                                    _openSlotBooking(o);
                                  } else {
                                    toast("⚠️ Slot already booked. Cannot rebook.");
                                  }
                                },
                                onLongPress: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          OrderDetailsScreen(orderId: orderId),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
