// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import 'order_unified_tracking_screen.dart';

/// ✅ ADDED: all
enum MasterOrderType { today, pending, all }

class MasterOrdersScreen extends StatefulWidget {
  final MasterOrderType type;

  const MasterOrdersScreen({super.key, required this.type});

  @override
  State<MasterOrdersScreen> createState() => _MasterOrdersScreenState();
}

class _MasterOrdersScreenState extends State<MasterOrdersScreen> {
  bool loading = false;
  bool _loadedOnce = false;

  String role = ""; // MASTER / MANAGER
  List<Map<String, dynamic>> orders = [];

  /// ✅ For ALL screen date filter
  DateTime selectedDate = DateTime.now();

  /// 🔹 Pending reasons
  final List<String> pendingReasons = const [
    "VEHICLE NOT AVAILABLE",
    "DRIVER NOT AVAILABLE",
    "PAYMENT ISSUE",
    "STOCK NOT AVAILABLE",
    "CUSTOMER REQUEST",
  ];

  // ================= ROLE HELPERS =================
  bool get isManager => role.contains("MANAGER");
  bool get isMaster => role.contains("MASTER");

  // ================= INIT =================
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _initRoleAndLoad();
    }
  }

  Future<void> _initRoleAndLoad() async {
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

  // ================= HELPERS =================
  String _safeStr(Map o, List<String> keys, {String fallback = "-"}) {
    for (final k in keys) {
      final v = o[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return fallback;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatCreated(dynamic raw) {
    if (raw == null) return "";
    final s = raw.toString().trim();
    if (s.isEmpty) return "";

    final looksPretty =
        RegExp(r"[A-Za-z]{3}").hasMatch(s) &&
        RegExp(r"\bAM\b|\bPM\b", caseSensitive: false).hasMatch(s);
    if (looksPretty) return s;

    try {
      final dt = DateTime.parse(s).toLocal();
      return DateFormat("dd MMM yyyy, hh:mm a").format(dt);
    } catch (_) {
      return s;
    }
  }

  void _openTracking(String orderId) {
    if (orderId.trim().isEmpty || orderId == "-") return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderUnifiedTrackingScreen(orderId: orderId),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() => selectedDate = picked);

    // Optional: reload to get fresh list
    // await _load();
  }

  // ================= LOAD ORDERS =================
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      Map<String, dynamic> res;

      /// ✅ ADDED: all loader
      if (widget.type == MasterOrderType.today) {
        res = await scope.ordersApi.today();
      } else if (widget.type == MasterOrderType.pending) {
        res = await scope.ordersApi.pending();
      } else {
        res = await scope.ordersApi.all(); // ✅ ALL ORDERS
      }

      dynamic raw = res["orders"] ?? res["items"] ?? res["data"] ?? res;
      if (raw is Map) raw = raw["orders"] ?? raw["items"] ?? raw["data"] ?? [];

      setState(() {
        orders = (raw is List ? raw : [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Load failed: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isPendingScreen = widget.type == MasterOrderType.pending;
    final isAllScreen = widget.type == MasterOrderType.all;

    final title = widget.type == MasterOrderType.today
        ? "Today Orders"
        : widget.type == MasterOrderType.pending
        ? "Pending Orders"
        : "All Orders";

    final dateLabel = DateFormat("dd MMM yyyy").format(selectedDate);

    /// ✅ Filter only for ALL screen
    final List<Map<String, dynamic>> viewOrders = isAllScreen
        ? orders.where((o) {
            final raw = _safeStr(o, [
              "createdAt",
              "createdOn",
              "createdDate",
              "orderDate",
              "date",
            ], fallback: "");
            final dt = _parseDate(raw);
            if (dt == null) return false;
            return _isSameDay(dt, selectedDate);
          }).toList()
        : orders;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAllScreen ? "$title ($dateLabel)" : title),
        actions: [
          /// ✅ ONLY FOR ALL screen
          if (isAllScreen)
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: _pickDate,
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : viewOrders.isEmpty
          ? Center(
              child: Text(
                isAllScreen ? "No orders for $dateLabel" : "No orders found",
                style: TextStyle(color: Colors.grey.shade400),
              ),
            )
          : ListView.builder(
              itemCount: viewOrders.length,
              itemBuilder: (_, i) {
                final o = viewOrders[i];

                final orderId = _safeStr(o, ["orderId", "id"]);
                final distributor = _safeStr(o, [
                  "distributorName",
                  "agencyName",
                ]);
                final amount =
                    o["amount"] ?? o["totalAmount"] ?? o["grandTotal"] ?? 0;

                // ✅ created date show in pending + all
                final createdRaw = _safeStr(o, [
                  "createdAt",
                  "createdOn",
                  "createdDate",
                  "orderDate",
                  "date",
                ], fallback: "");
                final createdPretty = createdRaw.isEmpty
                    ? ""
                    : _formatCreated(createdRaw);

                // =====================================================
                // ✅ SAVED REASON (BACKEND FIELD ONLY)  + DRAFT (UI ONLY)
                // =====================================================
                final String savedReason = _safeStr(o, [
                  "pendingReason",
                  "reason",
                  "pending_reason",
                ], fallback: "");

                // ✅ Draft selection (do NOT affect committed)
                final String draftReason = (o["pendingReasonDraft"] ?? "")
                    .toString();

                // ✅ committed ONLY if backend reason exists
                final bool reasonCommitted = savedReason.trim().isNotEmpty;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          distributor,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("Order ID: $orderId"),
                        const SizedBox(height: 4),
                        Text(
                          "₹$amount",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                        // ✅ created date show for pending + all
                        if ((isPendingScreen || isAllScreen) &&
                            createdPretty.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Created: $createdPretty",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ],

                        // ✅ MASTER tracking (Today + Pending + All)
                        if (isMaster) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => _openTracking(orderId),
                              icon: const Icon(Icons.track_changes, size: 18),
                              label: const Text("TRACK"),
                            ),
                          ),
                        ],

                        // =================================================
                        // 🔥 MANAGER ONLY – SELECT + SAVE (UNTIL COMMITTED)
                        // ✅ FIXED: dropdown select panna SAVE hide ஆகாது
                        // =================================================
                        if (isPendingScreen &&
                            isManager &&
                            !isMaster &&
                            !reasonCommitted) ...[
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: draftReason.trim().isEmpty
                                ? null
                                : draftReason,
                            hint: const Text("Select pending reason"),
                            items: pendingReasons
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                // ✅ ONLY draft changes
                                o["pendingReasonDraft"] = val;
                              });
                            },
                          ),
                          const SizedBox(height: 8),

                          ElevatedButton(
                            onPressed: draftReason.trim().isEmpty
                                ? null
                                : () async {
                                    final reasonToSave =
                                        (o["pendingReasonDraft"] ?? "")
                                            .toString()
                                            .trim();

                                    if (reasonToSave.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "❌ Select reason first",
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      final scope = TickinAppScope.of(context);

                                      debugPrint(
                                        "SAVE CLICKED => orderId=$orderId reason=$reasonToSave",
                                      );

                                      final resp = await scope.ordersApi
                                          .updatePendingReason(
                                            orderId: orderId.toString(),
                                            reason: reasonToSave,
                                          );

                                      debugPrint(
                                        "Update reason response => $resp",
                                      );

                                      if (resp["ok"] == false) {
                                        throw resp["message"] ??
                                            "Update failed";
                                      }

                                      // ✅ locally commit so UI shows immediately
                                      setState(() {
                                        o["pendingReason"] = reasonToSave;
                                        o["pendingReasonDraft"] = null;
                                      });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("✅ Reason saved"),
                                        ),
                                      );

                                      // ✅ reload (for master sync + fresh data)
                                      await _load();
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text("❌ Failed: $e")),
                                      );
                                    }
                                  },
                            child: const Text("SAVE"),
                          ),
                        ],

                        // =================================================
                        // 🔒 READ ONLY – MASTER + MANAGER (AFTER SAVE)
                        // =================================================
                        if (isPendingScreen && reasonCommitted) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.info,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Reason: $savedReason",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
