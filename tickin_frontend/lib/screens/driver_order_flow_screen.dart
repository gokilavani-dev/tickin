// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../api/location.dart';
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

  String get status => (order["status"] ?? "").toString().toUpperCase();

  String get orderId => (order["orderId"] ?? "").toString();

  /* ---------------- api helpers ---------------- */

  Future<void> _updateStatus(
    String nextStatus, {
    bool withLocation = false,
  }) async {
    setState(() => loading = true);

    try {
      final scope = TickinAppScope.of(context);
      final api = DriverApi(scope.httpClient);

      double? lat;
      double? lng;

      // 📍 Get location only when required
      if (withLocation) {
        final pos = await LocationService.getCurrentPosition();
        if (pos == null) {
          throw Exception("Location permission or GPS issue");
        }
        lat = pos.latitude;
        lng = pos.longitude;
      }

      // 🌐 Call backend
      final res = await api.updateStatus(
        orderId: orderId,
        nextStatus: nextStatus,
        lat: lat,
        lng: lng,
      );

      if (res["ok"] == false) {
        final dist = res["distanceMeters"];
        final radius = res["radiusMeters"];
        toast(
          "❌ ${res["message"] ?? "Try again"}"
          "${dist != null ? " • You are ${dist}m away" : ""}"
          "${radius != null ? " (need within ${radius}m)" : ""}",
        );
        return;
      }

      toast("✅ $nextStatus");
      setState(() => order = Map<String, dynamic>.from(res["order"]));
    } catch (e) {
      // 🧼 Clean error message
      final msg = e.toString().replaceFirst("Exception: ", "");
      toast("❌ $msg");
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
    switch (status) {
      case "DRIVER_ASSIGNED":
        return _actionButton(
          label: "▶️ Start Trip",
          onTap: () => _updateStatus("DRIVER_STARTED"),
          color: Colors.green,
        );

      case "DRIVER_STARTED":
        return _actionButton(
          label: "📍 Reach Distributor",
          onTap: () =>
              _updateStatus("DRIVER_REACHED_DISTRIBUTOR", withLocation: true),
          color: Colors.orange,
        );

      case "DRIVER_REACHED_DISTRIBUTOR":
        return _actionButton(
          label: "📦 Start Unload",
          onTap: () => _updateStatus("UNLOAD_START"),
          color: Colors.blueGrey,
        );

      case "UNLOAD_START":
        return _actionButton(
          label: "✅ End Unload",
          onTap: () => _updateStatus("UNLOAD_END"),
          color: Colors.indigo,
        );

      case "UNLOAD_END":
        return Column(
          children: [
            _actionButton(
              label: "📍 Reach Next Distributor",
              onTap: () => _updateStatus(
                "DRIVER_REACHED_DISTRIBUTOR",
                withLocation: true,
              ),
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

      case "WAREHOUSE_REACHED":
        return const Text(
          "🎉 Trip Completed",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        );

      default:
        return const Text("No actions available");
    }
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
