// ignore_for_file: deprecated_member_use, unused_import, prefer_iterable_wheretype

import 'package:flutter/material.dart';
import '../app_scope.dart';
import 'order_unified_tracking_screen.dart';
import 'DriverOrderFlowScreen.dart'; // ✅ ADD ONLY THIS IMPORT

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  bool loading = false;
  List<Map<String, dynamic>> orders = [];
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

  /// 🔥 LOAD ONLY DRIVER ASSIGNED ORDERS
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      // ✅ Driver assigned orders API
      final res = await scope.ordersApi.getDriverAssignedOrders();

      dynamic raw = res["orders"] ?? res["items"] ?? res["data"] ?? res;
      if (raw is Map) {
        raw = raw["orders"] ?? raw["items"] ?? raw["data"] ?? [];
      }

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
      if (o[k] != null && o[k].toString().isNotEmpty) {
        return o[k].toString();
      }
    }
    return "-";
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  /// 📍 TRACK ORDER → Unified Tracking Screen
  void _trackOrder(Map<String, dynamic> o) {
    final orderId = _safe(o, ["orderId", "id"]);

    if (orderId.isEmpty || orderId == "-") {
      toast("❌ OrderId missing");
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
        title: const Text("My Orders"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: loading
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
                  final distributor = _safe(o, [
                    "distributorName",
                    "agencyName",
                    "distributorId",
                  ]);

                  final amount = _num(
                    o["amount"] ?? o["totalAmount"] ?? o["grandTotal"],
                  ).toDouble();

                  final createdAt = _safe(o, [
                    "createdAt",
                    "created_at",
                    "date",
                  ]);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(
                        distributor,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Order: $orderId\nStatus: $status\nDate: $createdAt",
                      ),

                      /// ✅ TRACK BUTTON → Unified Tracking
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "₹${amount.toStringAsFixed(0)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _trackOrder(o),
                            icon: const Icon(Icons.location_on),
                            label: const Text("TRACK"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      /// ✅ TAP CARD → Driver Order Flow Screen
                      onTap: () {
                        if (orderId.isEmpty || orderId == "-") {
                          toast("❌ OrderId missing");
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DriverOrderFlowScreen(order: o),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
