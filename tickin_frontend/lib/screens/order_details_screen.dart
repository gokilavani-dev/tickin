// ignore_for_file: unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import '../app_scope.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool loading = false;
  Map<String, dynamic>? order;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (order == null) _load();
  }

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final res = await scope.ordersApi.getOrderById(widget.orderId);

      // ✅ Robust extraction:
      dynamic o = res["order"] ?? res["item"] ?? res["data"] ?? res;

      if (o is Map && o.containsKey("order")) {
        o = o["order"];
      }
      if (o is Map && o.containsKey("data")) {
        o = o["data"];
      }

      if (o is Map) {
        setState(() => order = o.cast<String, dynamic>());
      } else {
        setState(() => order = null);
      }
    } catch (e) {
      toast("❌ Load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (order?["items"] ?? order?["orderItems"] ?? []) as List;

    return Scaffold(
      appBar: AppBar(
        title: Text("Order ${widget.orderId}"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : order == null
          ? const Center(child: Text("No data"))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Distributor: ${(order?["distributorName"] ?? order?["agencyName"] ?? "-")}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text("Status: ${(order?["status"] ?? "-")}"),
                        const SizedBox(height: 6),
                        Text(
                          "Amount: ₹${_num(order?["amount"] ?? order?["totalAmount"] ?? order?["grandTotal"]).toStringAsFixed(2)}",
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Items",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...items.map((it) {
                  final m = it is Map ? it : {};
                  final pid = (m["productId"] ?? m["pid"] ?? "-").toString();
                  final pname =
                      (m["productName"] ??
                              m["name"] ??
                              m["itemName"] ??
                              m["product"]?["name"] ??
                              "")
                          .toString()
                          .trim();
                  final qty = _num(m["qty"] ?? m["quantity"]);
                  final price = _num(m["price"] ?? m["unitPrice"]);
                  final total = qty * price;
                  final titleText = pname.isNotEmpty ? "$pid  •  $pname" : pid;
                  return Card(
                    child: ListTile(
                      title: Text(titleText),
                      subtitle: Text(
                        "Qty: $qty  |  Unit: ₹${price.toStringAsFixed(2)}",
                      ),
                      trailing: Text("₹${total.toStringAsFixed(2)}"),
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}
