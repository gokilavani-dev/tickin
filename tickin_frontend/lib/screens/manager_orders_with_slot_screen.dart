// ignore_for_file: deprecated_member_use, unused_import, unused_local_variable

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../api/orders_flow_api.dart';

import 'manager_orders_flow_screen.dart';
import 'order_unified_tracking_screen.dart';

class ManagerOrdersWithSlotScreen extends StatefulWidget {
  const ManagerOrdersWithSlotScreen({super.key});

  @override
  State<ManagerOrdersWithSlotScreen> createState() =>
      _ManagerOrdersWithSlotScreenState();
}

class _ManagerOrdersWithSlotScreenState extends State<ManagerOrdersWithSlotScreen> {
  bool loading = false;
  bool loadedOnce = false;

  List<Map<String, dynamic>> flows = [];
                 String selectedDate = DateFormat("yyyy-MM-dd").format(DateTime.now());

  void toast(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loadedOnce) {
      loadedOnce = true;
      _load();
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
Future<void> _load() async {
  setState(() => loading = true);
  try {
    final scope = TickinAppScope.of(context);
    final api = OrdersFlowApi(scope.httpClient);

    final res = await api.slotConfirmedOrders(date: selectedDate);
    final list = (res["orders"] ?? res["data"] ?? []) as List;

    final parsed = list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    // ✅ filter should apply on parsed, NOT flows
    final cleaned = parsed.where((f) {
      final qty = (f["totalQty"] ?? f["qty"] ?? f["quantity"] ?? 0);
      final fk = (f["flowKey"] ?? f["orderId"] ?? "").toString();

      final q = (qty is num) ? qty.toInt() : int.tryParse("$qty") ?? 0;

      if (q <= 0) return false;
      if (fk.startsWith("LOC#")) return false;

      return true;
    }).toList();

    cleaned.sort((a, b) {
      final atA = (a["slotTime"] ?? "").toString();
      final atB = (b["slotTime"] ?? "").toString();
      return atA.compareTo(atB);
    });

    setState(() => flows = cleaned);
  } catch (e) {
    toast("❌ Load failed: $e");
  } finally {
    if (mounted) setState(() => loading = false);
  }
}
  String safe(Map o, List<String> keys) {
    for (final k in keys) {
      final v = o[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return "-";
  }

  num numSafe(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  void openTracking(String orderId) {
    if (orderId.isEmpty || orderId == "-") {
      toast("OrderId missing");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderUnifiedTrackingScreen(orderId: orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Slot Confirmed Orders"),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : flows.isEmpty
              ? const Center(child: Text("No Slot Confirmed Flows"))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: flows.length,
                  itemBuilder: (_, i) {
                    final f = flows[i];

                    final flowKey = safe(f, ["flowKey"]);
                    final slotTime = safe(f, ["slotTime"]);
                    final status = safe(f, ["status"]);
                    final vType = safe(f, ["vehicleType"]);

                    final orderIds = (f["orderIds"] ?? []) as List;
                    final distributors = (f["distributors"] ?? []) as List;

                    final totalQty = numSafe(f["totalQty"]);
                   
                    final firstOrderId =
                        orderIds.isNotEmpty ? orderIds.first.toString() : "-";

                    final distNames = <String>[];
                    for (final d in distributors) {
                      if (d is Map) {
                        final name = (d["distributorName"] ?? d["name"] ?? "").toString();
                        if (name.trim().isNotEmpty) distNames.add(name);
                      } else if (d != null) {
                        final name = d.toString();
                        if (name.trim().isNotEmpty) distNames.add(name);
                      }
                    }

                   final mainDist = distNames.isNotEmpty ? distNames.asMap().entries.map((e) => "D${e.key + 1}: ${e.value}").join(" | ")
    : "-";
                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          "Slot: $slotTime | Orders: ${orderIds.length}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Distributor: $mainDist\n"
                          "VehicleType: $vType | Qty: $totalQty |"
                          "Status: $status\n"
                          "FlowKey: $flowKey",
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: "Tracking",
                              icon: const Icon(Icons.track_changes),
                              onPressed: () => openTracking(firstOrderId),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                        onTap: () {
                          if (flowKey == "-" || flowKey.isEmpty) {
                            toast("FlowKey missing");
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManagerOrderFlowScreen(
                                flowKey: flowKey,
                                orderId: firstOrderId,
                                slotTime: slotTime,
                                distributors: distNames,
                                totalQty: totalQty,
                                statusFromSlot: status,
                              ),
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
