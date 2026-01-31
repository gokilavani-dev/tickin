// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, unused_local_variable

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../app_scope.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';

// ✅ UPDATE THIS IMPORT PATH if your slot file is in different folder
import 'slots/slot_booking_screen.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  bool loading = false;

  // from /api/sales/home
  List<Map<String, dynamic>> distributors = [];
  List<Map<String, dynamic>> products = [];

  String? selectedDistributorId; // distributorCode
  String? selectedDistributorName; // agencyName

  bool goalsLoading = false;

  /// goalsByProductId[normalizedProductId] = {remainingQty, usedQty, defaultGoal, ...}
  final Map<String, Map<String, dynamic>> goalsByProductId = {};

  final List<_OrderLine> lines = [_OrderLine()];

  // ---------- LIGHT PAGE THEME CONSTANTS ----------
  static const Color _ink = Color(0xFF0B1C2D); // dark blue text
  static const Color _brand = Color(0xFF1E3A8A); // deep blue button
  static const Color _bg = Colors.white;
  static const Color _card = Color(0xFFF3F4F6); // light grey
  static const Color _border = Color(0xFFCBD5E1);

  // ---------- Helpers: Normalize productIds ----------
  String _normPid(String pid) {
    final s = pid.toString().trim();
    if (s.startsWith("P#")) return s.substring(2);
    return s;
  }

  String _toBackendPid(String pid) {
    final s = pid.toString().trim();
    if (s.startsWith("P#")) return s;
    return "P#$s";
  }

  // ---------- Helpers: Safe field getters ----------
  String _distId(Map d) =>
      (d["distributorCode"] ?? d["distributorId"] ?? d["code"] ?? d["sk"] ?? "")
          .toString();

  String _distName(Map d) =>
      (d["distributorName"] ?? d["agencyName"] ?? d["name"] ?? "").toString();

  String _prodId(Map p) => _normPid(
    (p["productId"] ?? p["Product Id"] ?? p["id"] ?? p["code"] ?? "")
        .toString(),
  );

  String _prodName(Map p) =>
      (p["name"] ?? p["Product Name"] ?? p["productName"] ?? "").toString();

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    final s = v.toString().trim();
    return num.tryParse(s) ?? 0;
  }

  num _prodPrice(Map p) => _num(p["price"] ?? p["Price"] ?? p["unitPrice"]);

  // ---------- Totals ----------
  int get totalQty => lines.fold(0, (sum, l) => sum + (l.qty > 0 ? l.qty : 0));

  num get grandTotal => lines.fold<num>(
    0,
    (sum, l) => sum + (l.qty > 0 ? (l.qty * l.unitPrice) : 0),
  );

  int qtyForProduct(String productId) {
    final pid = _normPid(productId);
    int q = 0;
    for (final l in lines) {
      if (_normPid(l.productId ?? "") == pid && l.qty > 0) q += l.qty;
    }
    return q;
  }

  int? remainingForProduct(String productId) {
    final pid = _normPid(productId);
    final g = goalsByProductId[pid];
    if (g == null) return null;
    return int.tryParse("${g["remainingQty"] ?? g["remaining"] ?? ""}");
  }

  int? previewRemainingForProduct(String productId) {
    final pid = _normPid(productId);
    final rem = remainingForProduct(pid);
    if (rem == null) return null;
    return rem - qtyForProduct(pid);
  }

  bool goalExceededForProduct(String productId) {
    final pid = _normPid(productId);
    final prev = previewRemainingForProduct(pid);
    return prev != null && prev < 0;
  }

  // ---------- Lifecycle ----------
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (distributors.isEmpty && products.isEmpty) {
      TickinAppScope.of(context).tokenStore.getUserJson().then((uj) {});
      _loadHome();
    }
  }

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(m), backgroundColor: _ink));
  }

  // ---------- API calls ----------
  Future<void> _loadHome() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      // ✅ 1) BEFORE calling home(): see what app has stored for this user
      final userJson = await scope.tokenStore.getUserJson();

      // ✅ 2) Call backend home()
      final res = await scope.salesApi.home();

      final d =
          (res["distributors"] ?? res["distributorDropdown"] ?? []) as List;

      final p = (res["products"] ?? []) as List;

      setState(() {
        distributors = d
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        products = p
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

        if (selectedDistributorId != null &&
            !distributors.any((x) => _distId(x) == selectedDistributorId)) {
          selectedDistributorId = null;
          selectedDistributorName = null;
          goalsByProductId.clear();
        }

        for (final l in lines) {
          if (l.productId != null &&
              !products.any((x) => _prodId(x) == _normPid(l.productId!))) {
            l.productId = null;
            l.unitPrice = 0;
            l.qty = 0;
          }
        }
      });
    } catch (e) {
      toast(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _fetchMonthlyGoals(String distributorCode) async {
    setState(() => goalsLoading = true);
    try {
      final res = await TickinAppScope.of(
        context,
      ).goalsApi.monthly(distributorCode: distributorCode);

      final goals = (res["goals"] ?? []) as List;

      final map = <String, Map<String, dynamic>>{};
      for (final g in goals.whereType<Map>()) {
        final m = g.cast<String, dynamic>();
        final pidRaw = (m["productId"] ?? "").toString();
        if (pidRaw.isEmpty) continue;

        final pid = _normPid(pidRaw);
        map[pid] = m;
      }

      setState(() {
        goalsByProductId
          ..clear()
          ..addAll(map);
      });
    } catch (_) {
      setState(() => goalsByProductId.clear());
    } finally {
      if (mounted) setState(() => goalsLoading = false);
    }
  }

  Map<String, dynamic>? _findProduct(String productId) {
    final pid = _normPid(productId);
    for (final p in products) {
      if (_normPid(_prodId(p)) == pid) return p;
    }
    return null;
  }

  /// ✅ vehicleType based on totalQty (you can change)
  String _vehicleTypeFromQty(int totalQty) {
    if (totalQty > 60) return "FULL_TRUCK";
    return "HALF_TRUCK";
  }

  // ---------- Create Order ----------
  Future<void> _createOrder() async {
    if (selectedDistributorId == null) {
      toast("Select distributor");
      return;
    }

    final items = <Map<String, dynamic>>[];

    for (final l in lines) {
      if (l.productId == null) continue;
      if (l.qty <= 0) continue;

      if (goalExceededForProduct(l.productId!)) {
        toast("Goal exceeded for product ${l.productId}");
        return;
      }

      items.add({"productId": _toBackendPid(l.productId!), "qty": l.qty});
    }

    if (items.isEmpty) {
      toast("Add at least one product + qty");
      return;
    }

    setState(() => loading = true);

    try {
      final scope = TickinAppScope.of(context);

      // ✅ derive role + locationId + companyCode from userJson
      String role = "SALES";
      String locationId = "";
      String? companyCode;

      try {
        final userJson = await scope.tokenStore.getUserJson();
        if (userJson != null && userJson.isNotEmpty) {
          final u = jsonDecode(userJson) as Map<String, dynamic>;

          role = (u["role"] ?? u["userRole"] ?? "SALES")
              .toString()
              .toUpperCase();

          // convert role names for slot screen
          if (role.contains("MANAGER"))
            role = "MANAGER";
          else if (role.contains("SALES_OFFICER_VNR") ||
              role.contains("SALES OFFICER VNR")) {
            role = "SALES_OFFICER_VNR";
          } // ✅ keep VNR
          else if (role.contains("SALES OFFICER"))
            role = "SALES OFFICER";
          else if (role.contains("SALESMAN"))
            role = "SALESMAN";
          else if (role.contains("DISTRIBUTOR"))
            role = "DISTRIBUTOR";
          else
            role = "SALES";

          locationId = (u["locationId"] ?? u["pos"] ?? u["location"] ?? "")
              .toString();

          final companyId = (u["companyId"] ?? "").toString();
          if (companyId.contains("#")) companyCode = companyId.split("#").last;
          companyCode ??= (u["companyCode"] ?? "").toString();
        }
      } catch (_) {}

      final created = await scope.ordersApi.placePendingThenConfirmDraftIfAny(
        distributorId: selectedDistributorId!,
        distributorName: selectedDistributorName ?? selectedDistributorId!,
        items: items,
        companyCode: companyCode,
      );
      final bool isSalesOfficerVnr = role == "SALES_OFFICER_VNR";
      String orderId = (created["orderId"] ?? "").toString().trim();
      if (orderId.isEmpty) {
        final pk = (created["pk"] ?? "").toString().trim();
        if (pk.startsWith("ORDER#")) orderId = pk.substring("ORDER#".length);
      }
      final rawStatus = (created["status"] ?? "").toString().toUpperCase();
      final statusText = (rawStatus == "PENDING" || rawStatus == "DRAFT")
          ? "CONFIRMED"
          : rawStatus;

      final amount = grandTotal.toDouble();
      final vehicleType = _vehicleTypeFromQty(totalQty);

      // ✅ refresh goals + home
      await _fetchMonthlyGoals(selectedDistributorId!);
      await _loadHome();

      if (!mounted) return;

      // ✅ Order created dialog
      final goSlot = await showDialog<bool>(
        context: context,
        barrierDismissible:
            isSalesOfficerVnr, // ✅ outside tap close allowed only for VNR
        builder: (_) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text("Order Created ✅")),
              if (isSalesOfficerVnr)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
            ],
          ),
          content: Text(
            "Order ID: $orderId\nStatus: $statusText\nAmount: ₹${amount.toStringAsFixed(2)}",
          ),
          actions: isSalesOfficerVnr
              ? const [] // ✅ no buttons
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Stay Here"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Go to Slot Booking"),
                  ),
                ],
        ),
      );

      // ✅ Reset lines after success
      setState(() {
        lines
          ..clear()
          ..add(_OrderLine());
      });

      // ✅ If user wants slot booking -> open slot screen
      if (goSlot == true) {
        // ignore: use_build_context_synchronously
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SlotBookingScreen(
              role: role,
              distributorCode: selectedDistributorId!,
              distributorName:
                  selectedDistributorName ?? selectedDistributorId!,
              orderId: orderId,
              amount: amount,
            ),
          ),
        );

        // After slot booking pop -> refresh
        await _loadHome();
        await _fetchMonthlyGoals(selectedDistributorId!);
      }
    } catch (e) {
      toast("❌ ${e.toString()}");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------- UI helpers ----------
  void _addLine() => setState(() => lines.add(_OrderLine()));
  void _removeLine(int idx) => setState(() => lines.removeAt(idx));

  Widget _ellipsisText(String s) => Text(
    s,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(color: _ink),
  );

  InputDecoration _inputDec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _ink),
    filled: true,
    fillColor: _bg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _brand, width: 1.4),
    ),
  );

  Widget _goalPreviewCard() {
    if (selectedDistributorId == null) return const SizedBox.shrink();

    if (goalsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: LinearProgressIndicator(),
      );
    }

    final selectedPids = lines
        .map((l) => l.productId)
        .whereType<String>()
        .toSet()
        .toList();
    if (selectedPids.isEmpty) return const SizedBox.shrink();

    return Card(
      color: _card,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Goal Preview (Product-wise)",
              style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
            ),
            const SizedBox(height: 8),
            ...selectedPids.map((pidRaw) {
              final pid = _normPid(pidRaw);

              final rem = remainingForProduct(pid);
              final entered = qtyForProduct(pid);
              final prev = previewRemainingForProduct(pid);
              final exceeded = goalExceededForProduct(pid);

              final prod = _findProduct(pid);
              final name = prod == null ? "" : _prodName(prod);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _ellipsisText(
                        "$pid ${name.isEmpty ? "" : "- $name"}",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Rem: ${rem ?? "-"} | Qty: $entered | Prev: ${prev ?? "-"}",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: exceeded ? Colors.red : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text(
          "Create Orders",
          style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadHome,
            icon: const Icon(Icons.refresh, color: _ink),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final scope = TickinAppScope.of(context);
              await scope.tokenStore.clear();
              await OneSignal.logout();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt, color: _ink),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  dropdownColor: _bg,
                  value:
                      (selectedDistributorId != null &&
                          distributors.any(
                            (d) => _distId(d) == selectedDistributorId,
                          ))
                      ? selectedDistributorId
                      : null,
                  decoration: _inputDec("Distributor"),
                  items: distributors.map((d) {
                    final id = _distId(d);
                    final name = _distName(d);
                    final label = name.isEmpty ? id : "$id - $name";
                    return DropdownMenuItem<String>(
                      value: id,
                      child: _ellipsisText(label),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val == null) return;

                    final picked = distributors.firstWhere(
                      (x) => _distId(x) == val,
                      orElse: () => <String, dynamic>{},
                    );

                    setState(() {
                      selectedDistributorId = val;
                      selectedDistributorName = _distName(picked);
                      goalsByProductId.clear();
                    });

                    await _fetchMonthlyGoals(val);
                  },
                ),
                const SizedBox(height: 12),
                _goalPreviewCard(),
                const SizedBox(height: 12),
                const Text(
                  "Items",
                  style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
                ),
                const SizedBox(height: 8),
                ...List.generate(lines.length, (i) {
                  final l = lines[i];
                  final lineTotal = (l.qty > 0) ? (l.qty * l.unitPrice) : 0;
                  final exceeded = (l.productId != null)
                      ? goalExceededForProduct(l.productId!)
                      : false;

                  return Card(
                    color: _card,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            dropdownColor: _bg,
                            value:
                                (l.productId != null &&
                                    products.any(
                                      (p) =>
                                          _prodId(p) == _normPid(l.productId!),
                                    ))
                                ? l.productId
                                : null,
                            decoration: _inputDec("Product"),
                            items: products.map((p) {
                              final pid = _prodId(p); // normalized
                              final name = _prodName(p);
                              final label = name.isEmpty ? pid : "$pid - $name";
                              return DropdownMenuItem(
                                value: pid,
                                child: _ellipsisText(label),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              final prod = _findProduct(val);

                              setState(() {
                                l.productId = val; // normalized
                                l.unitPrice = prod == null
                                    ? 0
                                    : _prodPrice(prod);
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: l.qty == 0
                                      ? ""
                                      : l.qty.toString(),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: _ink),
                                  decoration: _inputDec("Qty").copyWith(
                                    errorText: exceeded
                                        ? "Goal exceeded"
                                        : null,
                                  ),
                                  onChanged: (v) {
                                    final n = int.tryParse(v.trim()) ?? 0;
                                    setState(() => l.qty = n);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InputDecorator(
                                  decoration: _inputDec("Unit Price"),
                                  child: Text(
                                    l.unitPrice > 0
                                        ? "₹${l.unitPrice.toStringAsFixed(2)}"
                                        : "-",
                                    style: const TextStyle(
                                      color: _ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Line Total: ₹${lineTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _addLine,
                                icon: const Icon(Icons.add, color: _brand),
                                label: const Text(
                                  "Add",
                                  style: TextStyle(
                                    color: _brand,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (lines.length > 1)
                                TextButton.icon(
                                  onPressed: () => _removeLine(i),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    "Remove",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Card(
                  color: _card,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Qty: $totalQty",
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Grand Total: ₹${grandTotal.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _createOrder,
                    child: const Text(
                      "Create Order",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _OrderLine {
  String? productId; // normalized ("001")
  int qty = 0;
  num unitPrice = 0;
}
