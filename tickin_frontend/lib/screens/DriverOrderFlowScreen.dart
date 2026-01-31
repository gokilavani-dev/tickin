// ignore_for_file: deprecated_member_use, file_names

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_scope.dart';
import '../api/driver_api.dart';

class DriverOrderFlowScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DriverOrderFlowScreen({super.key, required this.order});

  @override
  State<DriverOrderFlowScreen> createState() => _DriverOrderFlowScreenState();
}

class _DriverOrderFlowScreenState extends State<DriverOrderFlowScreen> {
  bool loading = false;
  late Map<String, dynamic> order;

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
  }

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ✅ clean + safe status
  String get status => (order["status"] ?? "").toString().trim().toUpperCase();
  String get orderId => (order["orderId"] ?? "").toString();

  /* ---------------- location ---------------- */

  Future<Position> _getLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception("Location service disabled");
    }

    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      throw Exception("Location permission denied forever");
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  /* ---------------- api helpers ---------------- */

  Future<void> _updateStatus(
    String nextStatus, {
    bool withLocation = false,
  }) async {
    if (loading) return;

    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final api = DriverApi(scope.httpClient);

      double? lat;
      double? lng;

      if (withLocation) {
        final pos = await _getLocation();
        lat = pos.latitude;
        lng = pos.longitude;
      }

      final res = await api.updateStatus(
        orderId: orderId,
        nextStatus: nextStatus,
        lat: lat,
        lng: lng,
      );

      // ✅ handle ok=false (Try again / errors)
      if (res["ok"] != true) {
        throw Exception(res["message"] ?? "Failed");
      }

      // ✅ must contain order
      final o = res["order"];
      if (o == null || o is! Map) {
        throw Exception("Invalid response: order missing");
      }

      setState(() {
        order = Map<String, dynamic>.from(o);
      });

      toast("✅ $nextStatus");
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /* ---------------- UI helpers ---------------- */

  Widget _actionButton({
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }

  /* ---------------- button logic ---------------- */

 Widget _buildActions() {
  final s = status;

  // ✅ DRIVER_ASSIGNED / DRIVER_STARTED (canonical)
  if (s == "DRIVER_ASSIGNED") {
    return _actionButton(
      label: "▶️ Start Trip",
      onTap: () => _updateStatus("DRIVER_STARTED"),
      color: Colors.green,
    );
  }

  if (s == "DRIVER_STARTED" || s == "DRIVE_STARTED") {
    return _actionButton(
      label: "📍 Reach Distributor",
      onTap: () => _updateStatus("DRIVER_REACHED_DISTRIBUTOR", withLocation: true),
      color: Colors.orange,
    );
  }

  // ✅ reached D1/D2
  if (s.startsWith("REACHED_D") || s == "DRIVER_REACHED_DISTRIBUTOR") {
    return _actionButton(
      label: "📦 Start Unload",
      onTap: () => _updateStatus("UNLOAD_START"),
      color: Colors.blueGrey,
    );
  }

  // ✅ unloading start D1/D2
  if (s.startsWith("UNLOADING_START_D") || s == "UNLOAD_START") {
    return _actionButton(
      label: "✅ End Unload",
      onTap: () => _updateStatus("UNLOAD_END"),
      color: Colors.indigo,
    );
  }

  // ✅ unloading end D1/D2
  if (s.startsWith("UNLOADING_END_D") || s == "UNLOAD_END") {
    return Column(
      children: [
        _actionButton(
          label: "📍 Reach Next Distributor",
          onTap: () => _updateStatus("DRIVER_REACHED_DISTRIBUTOR", withLocation: true),
          color: Colors.orange,
        ),
        const SizedBox(height: 10),
        _actionButton(
          label: "🏭 Reach Warehouse",
          onTap: () => _updateStatus("WAREHOUSE_REACHED"),
          color: Colors.red,
        ),
      ],
    );
  }

  if (s == "WAREHOUSE_REACHED") {
    return _actionButton(
      label: "✅ Complete Delivery",
      onTap: () => _updateStatus("DELIVERY_COMPLETED"),
      color: Colors.green,
    );
  }

  if (s == "DELIVERY_COMPLETED") {
    return const Text("🎉 Trip Completed",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green));
  }

  return const Text("No actions available");
}
  /* ---------------- build ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Order $orderId")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status: $status",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("Distributor: ${order["distributorName"] ?? "-"}"),
                    const SizedBox(height: 4),
                    Text(
                      "Vehicle: ${order["vehicleNo"] ?? order["vehicleType"] ?? "-"}",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildActions(),
          ],
        ),
      ),
    );
  }
}
