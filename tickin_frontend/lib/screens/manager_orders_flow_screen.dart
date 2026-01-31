// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads, unnecessary_null_in_if_null_operators, unused_element

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../api/orders_flow_api.dart';
import '../api/users_api.dart';
import '../api/vehicles_api.dart';
import 'order_unified_tracking_screen.dart';

class ManagerOrderFlowScreen extends StatefulWidget {
  final String flowKey;
  final String orderId;

  // ✅ OPTIONAL DETAILS FROM SLOT LIST
  final String? slotTime;
  final List<String>? distributors;
  final num? totalAmount;
  final num? totalQty;
  final String? statusFromSlot;

  const ManagerOrderFlowScreen({
    super.key,
    required this.flowKey,
    required this.orderId,
    this.slotTime,
    this.distributors,
    this.totalAmount,
    this.totalQty,
    this.statusFromSlot,
  });

  @override
  State<ManagerOrderFlowScreen> createState() => _ManagerOrderFlowScreenState();
}

class _ManagerOrderFlowScreenState extends State<ManagerOrderFlowScreen> {
  bool loading = false;

  Map<String, dynamic>? flowOrder;
  String status = "";

  String? selectedVehicle;
  String? selectedDriverId;

  List<String> vehicles = [];
  List<Map<String, dynamic>> drivers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  void toast(String m) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    });
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  String _s(dynamic v) => (v ?? "").toString();

  String _driverId(Map<String, dynamic> d) {
    final raw = d["id"] ??
        d["pk"] ??
        d["driverId"] ??
        d["_id"] ??
        d["userId"] ??
        d["mobile"] ??
        "";
    return raw.toString();
  }

  String? _extractDriverIdFromFlow(Map<String, dynamic>? flow) {
    if (flow == null) return null;

    final raw = flow["driverId"] ??
        flow["assignedDriverId"] ??
        flow["driver_id"] ??
        (flow["driver"] is Map ? flow["driver"]["id"] : null) ??
        (flow["driver"] is Map ? flow["driver"]["_id"] : null) ??
        (flow["driverDetails"] is Map ? flow["driverDetails"]["id"] : null) ??
        (flow["driverDetails"] is Map ? flow["driverDetails"]["_id"] : null);

    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s == "null") return null;
    return s;
  }

  String _driverName(Map<String, dynamic> d) {
    return (d["name"] ?? d["userName"] ?? d["mobile"] ?? "Driver").toString();
  }

  // ✅ Remove duplicate distributor orders (fix amount double)
 List<Map<String, dynamic>> _uniqueOrders(List<Map<String, dynamic>> orders) {
  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];

  for (final o in orders) {
    final id = _s(o["distributorId"] ??
        o["distributor_id"] ??
        o["distributorCode"] ??     // ✅ backend order meta has this mostly
        o["distCode"]);

    final name = _s(o["distributorName"] ??
        o["distributor"] ??
        o["distName"]);

    // ✅ fallback: distributor details இல்லனா orderId use பண்ணு
    final orderId = _s(o["orderId"] ?? o["pk"]);

    final key = id.trim().isNotEmpty
        ? id.trim()
        : (name.trim().isNotEmpty ? name.trim().toUpperCase() : orderId);

    if (key.trim().isEmpty) continue;

    if (!seen.contains(key)) {
      seen.add(key);
      unique.add(o);
    }
  }

  return unique;
}
  String _trackingOrderId(Map<String, dynamic> flow) {
  // ✅ 0) If backend already sends a FULL id directly (best)
  final fullDirect = flow["fullOrderId"] ??
      flow["masterFullOrderId"] ??
      flow["masterOrderId"] ??
      flow["masterOrder"] ??
      null;

  if (fullDirect != null) {
    final s = fullDirect.toString().trim();
    if (s.isNotEmpty && s != "null") return s;
  }

  // ✅ 1) If flow has a "masterOrderId" but mergedIntoOrderId exists,
  // prefer mergedIntoOrderId (FULL)
  final merged = flow["mergedIntoOrderId"] ??
      flow["mergedInto"] ??
      flow["finalOrderId"] ??
      flow["finalOrder"] ??
      null;

  if (merged != null) {
    final s = merged.toString().trim();
    if (s.isNotEmpty && s != "null") return s;
  }

  // ✅ 2) If orders[] exists, try to find ORD_FULL_... inside it
  final orders = (flow["orders"] is List) ? (flow["orders"] as List) : const [];
  for (final o in orders) {
    if (o is Map) {
      final oid = (o["fullOrderId"] ?? o["mergedIntoOrderId"] ?? o["orderId"] ?? o["id"])?.toString().trim();
      if (oid != null && oid.isNotEmpty && oid != "null") {
        // If FULL order id exists, prefer it
        if (oid.startsWith("ORD_FULL_")) return oid;
      }
    }
  }

  // ✅ 3) Some flows store list of orderIds / child ids
  final list = (flow["orderIds"] is List)
      ? (flow["orderIds"] as List)
          .map((e) => e.toString())
          .where((x) => x.trim().isNotEmpty && x != "null")
          .toList()
      : <String>[];

  // If list has ORD_FULL_... pick that
  for (final x in list) {
    final s = x.trim();
    if (s.startsWith("ORD_FULL_")) return s;
  }

  // ✅ 4) fallback to flow.orderId if present
  final direct = flow["orderId"] ?? flow["id"] ?? null;
  if (direct != null) {
    final s = direct.toString().trim();
    if (s.isNotEmpty && s != "null") return s;
  }

  // ✅ 5) final fallback: widget.orderId
  return widget.orderId;
}

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      final flowApi = OrdersFlowApi(scope.httpClient);
      final usersApi = UsersApi(scope.httpClient);
      final vehiclesApi = VehiclesApi(scope.httpClient);

      final fRes = await flowApi.getOrderFlowByKey(widget.flowKey);

      final f = (fRes["order"] ??
              (fRes["data"]?["order"]) ??
              fRes["data"] ??
              fRes) as Map<String, dynamic>?;

      final st = (f?["status"] ?? widget.statusFromSlot ?? "").toString();

      final vList = await vehiclesApi.getAvailable();

      final dRes = await usersApi.getDrivers();
      final dList = (dRes["drivers"] ?? []) as List;

      setState(() {
        flowOrder = f;
        status = st;

        vehicles = vList;
        drivers = dList.map((e) => Map<String, dynamic>.from(e)).toList();

        selectedVehicle =
            (flowOrder?["vehicleNo"] ?? flowOrder?["vehicleType"])?.toString();

        final newDriverId = _extractDriverIdFromFlow(flowOrder);
        if (newDriverId != null) {
          selectedDriverId = newDriverId;
        }
      });
    } catch (e) {
      toast("❌ Load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _reloadFlow() async {
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final fRes = await flowApi.getOrderFlowByKey(widget.flowKey);

      final f = (fRes["order"] ??
              (fRes["data"]?["order"]) ??
              fRes["data"] ??
              fRes) as Map<String, dynamic>?;

      final st = (f?["status"] ?? widget.statusFromSlot ?? "").toString();

      setState(() {
        flowOrder = f;
        status = st;

        selectedVehicle =
            (flowOrder?["vehicleNo"] ?? flowOrder?["vehicleType"])?.toString();

        final newDriverId = _extractDriverIdFromFlow(flowOrder);
        if (newDriverId != null) {
          selectedDriverId = newDriverId;
        }
      });
    } catch (e) {
      toast("❌ Refresh failed: $e");
    }
  }

  Future<void> _vehicleSelected(String v) async {
    setState(() {
      loading = true;
      selectedVehicle = v;
    });

    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.vehicleSelectedSmart(
        flowKey: widget.flowKey,
        orderId: widget.orderId,
        vehicleNo: v,
      );

      if (res["ok"] == false) {
        throw Exception(res["message"] ?? "Vehicle select failed");
      }

      toast("✅ Vehicle Selected");
      await _reloadFlow();
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadingStart() async {
    if (selectedVehicle == null || selectedVehicle!.isEmpty) {
      toast("⚠️ Select vehicle first");
      return;
    }

    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.loadingStart(widget.flowKey);
      if (res["ok"] == false) {
        throw Exception(res["message"] ?? "Loading Start failed");
      }

      toast("✅ Loading Started");
      await _reloadFlow();
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadingEnd() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.loadingEnd(widget.flowKey);
      if (res["ok"] == false) {
        throw Exception(res["message"] ?? "Loading End failed");
      }

      toast("✅ Loading Ended");
      await _reloadFlow();
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _assignDriver(String driverId) async {
    if (selectedVehicle == null || selectedVehicle!.isEmpty) {
      toast("⚠️ Select vehicle first");
      return;
    }

    setState(() => loading = true);

    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.assignDriver(
        flowKey: widget.flowKey,
        driverId: driverId,
        vehicleNo: selectedVehicle,
      );

      if (res["ok"] == false) {
        throw Exception(res["message"] ?? "Assign Driver failed");
      }

      setState(() {
        selectedDriverId = driverId;
      });

      await _reloadFlow();
      toast("✅ Driver Assigned");
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showItemsPopup(Map<String, List<Map<String, dynamic>>> itemsByDist) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(14),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Loading Items",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: itemsByDist.isEmpty
                  ? const Center(child: Text("No items"))
                  : ListView(
                      children: itemsByDist.entries.map((e) {
                        final dist = e.key;
                        final items = e.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dist,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const Divider(),
                                ...items.map((it) {
                                  final name = _s(it["name"] ??
                                      it["itemName"] ??
                                      it["productName"] ??
                                      "-");
                                  final qty = _s(it["qty"] ??
                                      it["quantity"] ??
                                      it["totalQty"] ??
                                      0);
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(name)),
                                        Text("x$qty",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            )
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(String title, List<Map<String, dynamic>> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text("No items found")
            else
              ...items.map((m) {
                final name = _s(m["name"] ??
                    m["itemName"] ??
                    m["productName"] ??
                    "-");
                final qty = _s(m["qty"] ?? m["quantity"] ?? m["totalQty"] ?? 0);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(name)),
                      Text("x$qty",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
@override
Widget build(BuildContext context) {
  final f = flowOrder ?? {};

  // ✅ orders array (mergeKey GEO flow includes this)
  final rawOrders = (f["orders"] ?? []) as List;
  final ordersRaw = rawOrders.map((e) => Map<String, dynamic>.from(e)).toList();

  // ✅ remove duplicate distributor orders (fix merge duplicates)
  final uniqueOrders = _uniqueOrders(ordersRaw);

  // ✅ Items separated by distributor
  final Map<String, List<Map<String, dynamic>>> itemsByDist = {};

  for (final o in uniqueOrders) {
    final dist = _s(
      o["distributorName"] ??
          o["distributor"] ??
          o["distributorCode"] ??
          o["distCode"] ??
          "Unknown",
    ).trim();

    final items = List<Map<String, dynamic>>.from(
      o["loadingItems"] ?? o["items"] ?? o["orderItems"] ?? [],
    );

    itemsByDist.putIfAbsent(dist, () => []);
    itemsByDist[dist]!.addAll(items);
  }

  // ✅ CHANGE 3 fallback: if no items in orders, use root loadingItems
  if (itemsByDist.isEmpty) {
    final directItems = (f["loadingItems"] ?? []) as List;
    if (directItems.isNotEmpty) {
      itemsByDist["Loading Items"] =
          directItems.map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  // ✅ totalQty (fallback root totalQty)
  final totalQty = uniqueOrders.isNotEmpty
      ? _num(uniqueOrders.fold<num>(
          0,
          (p, o) => p + _num(o["totalQty"] ?? o["qty"] ?? 0),
        ))
      : _num(f["totalQty"] ?? widget.totalQty);

  // ✅ totalAmount (backend uses grandTotal)
  final totalAmount = uniqueOrders.isNotEmpty
      ? _num(uniqueOrders.fold<num>(
          0,
          (p, o) =>
              p +
              _num(o["grandTotal"] ??
                  o["totalAmount"] ??
                  o["amount"] ??
                  o["total"] ??
                  0),
        ))
      : _num(f["grandTotal"] ?? f["totalAmount"] ?? widget.totalAmount);

  // ✅ Distributor Names (fallback distributorCode)
  final distNames = <String>[];
  for (final o in uniqueOrders) {
    final dn = _s(o["distributorName"] ??
            o["distributor"] ??
            o["distributorCode"] ??
            o["distCode"] ??
            "")
        .trim();
    if (dn.isNotEmpty &&
        dn != "null" &&
        !distNames.any((x) => x.toLowerCase() == dn.toLowerCase())) {
      distNames.add(dn);
    }
  }
  final distText = distNames.isNotEmpty ? distNames.join(" , ") : "-";

  // ✅ Status
  final st = (status.isNotEmpty ? status : (widget.statusFromSlot ?? ""))
      .toUpperCase();

  final hasVehicle =
      selectedVehicle != null && selectedVehicle!.trim().isNotEmpty;

  final isConfirmed = st == "CONFIRMED" || st == "SLOT_BOOKED";
  final isLoadingStarted = st == "LOADING_STARTED";
  final isLoadingDone = st == "LOADING_COMPLETED";
  final isDriverAssigned = st == "DRIVER_ASSIGNED";

  final canPickVehicle =
      isConfirmed && !isLoadingStarted && !isLoadingDone && !isDriverAssigned;

  final canStartLoading =
      isConfirmed && hasVehicle && !isLoadingStarted && !isLoadingDone;

  final canEndLoading = isLoadingStarted && !isLoadingDone;

  final canAssignDriver = isLoadingDone && !isDriverAssigned;

  // ✅ showItems based on availability (not status only)
  final showItems = itemsByDist.isNotEmpty;

  // ✅ Vehicle dropdown safe bind
  final cleanedVehicle = selectedVehicle?.trim().toUpperCase();
  final vehicleValue = (cleanedVehicle != null &&
          vehicles.map((e) => e.toUpperCase()).contains(cleanedVehicle))
      ? vehicles.firstWhere((e) => e.toUpperCase() == cleanedVehicle)
      : null;

  // ✅ Driver dropdown safe bind
  final cleanedDriver = selectedDriverId?.trim();

  return Scaffold(
    appBar: AppBar(
      title: const Text("Manager Flow"),
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        IconButton(
          icon: const Icon(Icons.track_changes),
          onPressed: () {
            final id = _trackingOrderId(f);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderUnifiedTrackingScreen(orderId: id),
              ),
            );
          },
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ✅ SUMMARY CARD
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("FlowKey: ${widget.flowKey}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text("SlotTime: ${widget.slotTime ?? '-'}"),
                      const SizedBox(height: 6),
                      Text("Distributors: $distText"),
                      const Divider(),
                      Text("TotalQty: $totalQty"),
                      Text("TotalAmount: ₹$totalAmount"),
                      const SizedBox(height: 6),
                      Text("Status: ${status.isNotEmpty ? status : (widget.statusFromSlot ?? '-')}"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ VEHICLE DROPDOWN
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<String>(
                    value: vehicleValue,
                    decoration: const InputDecoration(
                      labelText: "Select Vehicle",
                      border: OutlineInputBorder(),
                    ),
                    items: vehicles
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: canPickVehicle
                        ? (v) {
                            if (v == null) return;
                            _vehicleSelected(v);
                          }
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ START / END BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canStartLoading ? _loadingStart : null,
                      child: const Text("Loading Start"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canEndLoading ? _loadingEnd : null,
                      child: const Text("Loading End"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ ITEMS SEPARATE BY DISTRIBUTOR / ROOT
              if (showItems) ...[
                ...itemsByDist.entries.map((e) {
                  return _itemsCard("${e.key} Loading Items", e.value);
                }).toList(),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _showItemsPopup(itemsByDist),
                  child: const Text("View Loading Items"),
                ),
                const SizedBox(height: 12),
              ],

              // ✅ ASSIGN DRIVER DROPDOWN
              if (canAssignDriver)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<String>(
                      value: (cleanedDriver != null &&
                              drivers.any((d) =>
                                  _driverId(d).trim() == cleanedDriver))
                          ? cleanedDriver
                          : null,
                      decoration: const InputDecoration(
                        labelText: "Assign Driver",
                        border: OutlineInputBorder(),
                      ),
                      items: drivers.map((d) {
                        final id = _driverId(d).trim();
                        final name = _driverName(d);
                        return DropdownMenuItem(value: id, child: Text(name));
                      }).toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        _assignDriver(id);
                      },
                    ),
                  ),
                ),

              if (isDriverAssigned)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    "✅ Driver Assigned",
                    style: TextStyle(fontWeight: FontWeight.bold ),
                  ),
                ),
            ],
          ),
  );
}
}